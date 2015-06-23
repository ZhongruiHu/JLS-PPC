function [XHat,P] = JLSKF(XHat,P,yKF,USent,D_cHat,Nx,Nv,Nu,Np,D_m,A,Bu,...
    E,M,C,W,V,t,tKF,tNoACK,covPriorAdj,uOptions,alpha_cBar)
% [XHat,P] = JLSKF(XHat,P,yKF,USent,D_cHat,Nx,Nv,Nu,Np,D_m,A,Bu,...
%     E,M,C,W,V,t,tKF,tNoACK,covPriorAdj,uOptions,alpha_cBar)
%
% XHat is state estimate (system + buffer)
% P is error cov. 
% yKF: meas into KF, D_m: meas success matrix
% USent: control plan as sent (used if packet successful)
% D_cHat: estimate of control jump variable
% (std. system vars)
% W, V: process, meas. noise covariances
% uOptions: NU x tNoACK vector of alternate control actions that might be
%   applied depending on control packet success history
% alpha_cBar: control packet success probability
% covPriorAdj: toggles using the adjustment
% tNoACK: time since ACK received (for covPriorAdj)
% t: true time at estimator when fcn is called (mostly for debugging)
% tKF: physical time step KF is updating -- xHat(tKF|tKF) posterior

% v1.0 6/13/2015
% v1.1 6/16/2015

% TO DO: 
% more Pstars for SISO  -- AUTOMATE 
% (need to load-in "lookup table")

% add in printDebug

% covariance prior (standard)
Ppre0 = A*P*A' + W ; %P_{t+1|t}

if( covPriorAdj && (max(tNoACK)>0) )
          
    % SENT control command for step t
    ut = E*USent;

    dU = zeros(size(ut,1),max(tNoACK));
    for i = 1:max(tNoACK)
        dU(:,i) = (ut - uOptions(:,i));
    end
    %{
    fprintf('\nt=%d, KF: ut=',t)
    disp(ut)
    fprintf('\nt=%d, KF: dU=',t)
    disp(dU)
    %}
        
    % Single input systems
    if(size(Bu,2)==1)
        if(tNoACK>2)
            fprintf('\nt=%d, KF tKF=%d ERROR - ACKDropped too large, using Pstar2\n',t,tKF)
            tNoACK=2;
        end
        
        
        
        % AUTOMATED COMPUTATION AND SUMMING OF TERMS BASED ON tNoACK
        % MAY BE FASTEST TO DUMP LOOKUP TABLE OF STRINGS HERE? 
        % USE EVAL?  ... OR SOMETHING BETTER?
        % PROBABLY SLOW TO ACTUALLY USE SYMBOLIC VARS
        
        
        
        % NOTE -- uHistory are from prev. COMPUTED buffers
        % they are not necessarily shifts of the buffer estimate in Xh        
        Pstar = zeros(size(P,1),size(P,2),10);
        if(tNoACK==1)
            
            Pstar(:,:,1) = (alpha_cBar*(1-alpha_cBar))*Bu*dU(:,1)*...
                dU(:,1)'*Bu';
            %Pstar2 = 0;
            if(size(Pstar,1)==1)
                fprintf('\nt=%d, KF tKF=%d, P* = %f \n',t, tKF,...
                    squeeze(Pstar(:,:,1)))
            else
                fprintf('\nt=%d, KF tKF=%d, P* = \n',t, tKF)
                disp(squeeze(Pstar(:,:,1)))
            end
            
        elseif(tNoACK==2)
            
            % uses diff with 1-step prev. plan
            Pstar(:,:,1) = (- alpha_cBar^4 + 2*alpha_cBar^3 - ...
                2*alpha_cBar^2 + alpha_cBar)*Bu*dU(:,2)*dU(:,2)'*Bu';
            % uses diff with 2-step prev. plan (earliest)
            Pstar(:,:,2) = (- alpha_cBar^4 + 4*alpha_cBar^3 - ...
                5*alpha_cBar^2 + 2*alpha_cBar)*Bu*dU(:,1)*dU(:,1)'*Bu';
            if(size(Pstar,1)==1)
                fprintf('\nt=%d, KF tKF=%d, P**(1) = %f, P**(2) = %f \n',...
                    t,tKF,squeeze(Pstar(:,:,1)),squeeze(Pstar(:,:,2)))
            else
                fprintf('\nt=%d, KF tKF=%d, P**(1) =    , P**(2) =     \n',...
                    t,tKF)
                disp([squeeze(Pstar(:,:,1)),squeeze(Pstar(:,:,2))])
            end

        elseif(tNoACK>2)
            
            % (fill in with more Pstars...)
            %Pstar1 = 0.00111; Pstar2 = 0.00222; Pstar3 = 0.00333; 
            disp('(Pstar>2)')
            
        end
        
        Ppre = Ppre0+sum(Pstar,3);
        
    else
        
        % single-step: Pstar
        
        % (zero out dU manually for ACK'd channels?)
        
        % off diagonal elements
        EAZA = diag(alpha_cBar)*dU(:,1)*dU(:,1)'*diag(alpha_cBar);   
        
        % replace diagonal elements
        dum = diag(alpha_cBar)*dU(:,1)*dU(:,1)';     
        for i = 1:Nu; EAZA(i,i) = dum(i,i) ; end;
        
        Pstar = Bu*(EAZA - diag(alpha_cBar)*dU(:,1)*dU(:,1)'*...
            diag(alpha_cBar))*Bu';
        
        Ppre = Ppre0+Pstar;
        fprintf('\nt=%d, KF tKF=%d, MIMO P*: \n',t,tKF)
        disp(Pstar)
        
    end
else
    
    Ppre = Ppre0;
    
end

% Kalman gain = fcn of Ppre
L = ((Ppre*C')/(C*Ppre*C'+V))*D_m;   % L_{t}
P = Ppre - L*(C*Ppre);

% propagate system
I = eye(size(A));
AAHat = [(I-L*C)*A,(I-L*C)*Bu*E*M*(eye(Np*Nu*Nv)-D_cHat);...
    zeros(Nv*Np*Nu,Nx),M*(eye(Np*Nu*Nv)-D_cHat)];
BUHat = [(I-L*C)*Bu*E*D_cHat;D_cHat];
XHat = AAHat*XHat + BUHat*USent+[L;zeros(Np*Nu*Nv,size(yKF,1))]*yKF;

end
