function M = fixedrankfactory_2factors_preconditioned(m, n, k)
% Manifold of m-by-n matrices of rank k with new balanced quotient geometry
%
% function M = fixedrankNewLRquotientfactory(m, n, k)
%
% This follows the quotient geometry described in the following paper:
% B. Mishra, K. Adithya Apuroop and R. Sepulchre,
% "A Riemannian geometry for low-rank matrix completion",
% arXiv, 2012.
%
% Paper link: http://arxiv.org/abs/1211.1550
%
% This geoemtry is tuned to least square problems such as low-rank matrix
% completion and is different from the geometry
% "fixedrankLRquotientfactory".
%
% A point X on the manifold is represented as a structure with two
% fields: L and R. The matrices L (mxk) and R (nxk) are full column-rank
% matrices.
%
% Tangent vectors are represented as a structure with two fields: L, R

% This file is part of Manopt: www.manopt.org.
% Original author: Bamdev Mishra, Dec. 30, 2012.
% Contributors:
% Change log:



M.name = @() sprintf('LR''(tuned for least square problems) quotient manifold of %dx%d matrices of rank %d', m, n, k);

M.dim = @() (m+n-k)*k;

% The choice of metric is motivated by symmetry and tuned to least square
% objective function
M.inner = @iproduct;
    function ip = iproduct(X, eta, zeta)
        if ~all(isfield(X,{'LtL','RtR','invRtR','invLtL'}) == 1)
            X.LtL = X.L'*X.L;
            X.RtR = X.R'*X.R;
            X.invLtL = eye(size(X.L,2))/ X.LtL;
            X.invRtR = eye(size(X.R,2))/ X.RtR;
        end
        
        ip = trace(X.RtR*(eta.L'*zeta.L)) + trace(X.LtL*(eta.R'*zeta.R));
    end

M.norm = @(X, eta) sqrt(M.inner(X, eta, eta));

M.dist = @(x, y) error('fixedrankNewLRquotientfactory.dist not implemented yet.');

M.typicaldist = @() 10*k;

symm = @(M) .5*(M+M');

M.egrad2rgrad = @egrad2rgrad;
    function eta = egrad2rgrad(X, eta)
        if ~all(isfield(X,{'LtL','RtR','invRtR','invLtL'}) == 1)
            X.LtL = X.L'*X.L;
            X.RtR = X.R'*X.R;
            X.invLtL = eye(size(X.L,2))/ X.LtL;
            X.invRtR = eye(size(X.R,2))/ X.RtR;
        end
        
        eta.L = eta.L*X.invRtR;
        eta.R = eta.R*X.invLtL;
    end

M.ehess2rhess = @ehess2rhess;
    function Ress = ehess2rhess(X, egrad, ehess, eta)
        if ~all(isfield(X,{'LtL','RtR','invRtR','invLtL'}) == 1)
            X.LtL = X.L'*X.L;
            X.RtR = X.R'*X.R;
            X.invLtL = eye(size(X.L,2))/ X.LtL;
            X.invRtR = eye(size(X.R,2))/ X.RtR;
        end
        
        % Riemannian gradient
        rgrad = egrad2rgrad(X, egrad);
        
        % Directional derivative of the Riemannian gradient
        Ress.L = ehess.L*X.invRtR - 2*egrad.L*(X.invRtR * symm(eta.R'*X.R) * X.invRtR);
        Ress.R = ehess.R*X.invLtL - 2*egrad.R*(X.invLtL * symm(eta.L'*X.L) * X.invLtL);
         
        % We still need a correction factor for the non-constant metric
        Ress.L = Ress.L + rgrad.L*(symm(eta.R'*X.R)*X.invRtR) + eta.L*(symm(rgrad.R'*X.R)*X.invRtR) - X.L*(symm(eta.R'*rgrad.R)*X.invRtR);
        Ress.R = Ress.R + rgrad.R*(symm(eta.L'*X.L)*X.invLtL) + eta.R*(symm(rgrad.L'*X.L)*X.invLtL) - X.R*(symm(eta.L'*rgrad.L)*X.invLtL);
        
        % Project on the horizontal space
        Ress = M.proj(X, Ress);
        
    end

M.proj = @projection;
    function etaproj = projection(X, eta)
        if ~all(isfield(X,{'LtL','RtR','invRtR','invLtL'}) == 1)
            X.LtL = X.L'*X.L;
            X.RtR = X.R'*X.R;
            X.invLtL = eye(size(X.L,2))/ X.LtL;
            X.invRtR = eye(size(X.R,2))/ X.RtR;
        end
        
        Lambda =  (eta.R'*X.R)*X.invRtR  -   X.invLtL*(X.L'*eta.L);
        Lambda = Lambda/2;
        etaproj.L = eta.L + X.L*Lambda;
        etaproj.R = eta.R - X.R*Lambda';
    end

M.retr = @retraction;
    function Y = retraction(X, eta, t)
        if nargin < 3
            t = 1.0;
        end
        Y.L = X.L + t*eta.L;
        Y.R = X.R + t*eta.R;
        
        % Numerical conditioning step: A simpler version.
        % We need to ensure that L and R are do not have very relative
        % skewed norms.
        
        scaling = norm(X.L, 'fro')/norm(X.R, 'fro');
        scaling = sqrt(scaling);
        Y.L = Y.L / scaling;
        Y.R = Y.R * scaling;
        
        % These are reused in the computation of the gradient and Ressian
        Y.LtL = Y.L'*Y.L;
        Y.RtR = Y.R'*Y.R;
        Y.invLtL = eye(size(Y.L, 2))/ Y.LtL;
        Y.invRtR = eye(size(Y.R, 2))/ Y.RtR;
    end


M.exp = @exponential;
    function Y = exponential(X, eta, t)
        if nargin < 3
            t = 1.0;
        end
        
        Y = retraction(X, eta, t);
        warning('manopt:fixedrankNewLRquotientfactory:exp', ...
            ['Exponential for fixed rank ' ...
            'manifold not implemented yet. Used retraction instead.']);
    end

M.hash = @(X) ['z' manopt.privatetools.hashmd5(...
    [X.L(:) ; X.R(:)]  )];

M.rand = @random;

    function X = random()
        X.L = randn(m, k);
        X.R = randn(n, k);
    end

M.randvec = @randomvec;
    function eta = randomvec(X)
        eta.L = randn(m, k);
        eta.R = randn(n, k);
        eta = projection(X, eta);
        nrm = M.norm(X, eta);
        eta.L = eta.L / nrm;
        eta.R = eta.R / nrm;
    end

M.lincomb = @lincomb;

M.zerovec = @(X) struct('L', zeros(m, k),'R', zeros(n, k));

M.transp = @(x1, x2, d) projection(x2, d);

end

% Linear combination of tangent vectors
function d = lincomb(x, a1, d1, a2, d2) %#ok<INUSL>

if nargin == 3
    d.L = a1*d1.L;
    d.R = a1*d1.R;
elseif nargin == 5
    d.L = a1*d1.L + a2*d2.L;
    d.R = a1*d1.R + a2*d2.R;
else
    error('Bad use of fixedrankLRquotientfactory.lincomb.');
end

end





