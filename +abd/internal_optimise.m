classdef internal_optimise < handle
%   Find the optimum stacking sequence based on the load and selected
%   failure measure.
%
%   DO NOT RUN THIS FUNCTION.
%
%   Layup Analysis Tool 2.4 Copyright Louis Vallance 2023
%   Last modified 10-May-2023 10:16:13 UTC
%

%% - DO NOT EDIT BELOW LINE
%_______________________________________________________________________
%%

    methods(Static = true, Access = public)
        %% RUN THE OPTIMISER
        function [BEST_SEQUENCE, CRITERION_BUFFER, MIN_CRITERION] =...
                main(OUTPUT_OPTIMISED, nargin, nPlies, nPlies_points,...
                nSectionPoints, z, z_points, Q11, Q22, Q66, Q12,...
                A11_points, A22_points, B11_points, B22_points,...
                tolerance, XT, XC, YT, YC, S, C12, B12, XET, XEC, YET,...
                YEC, SE, ALPHA, XHT, XHC, YHT, YHC, SHX, SHY, deltaT,...
                deltaM, Nxx, Nyy, Nxy, Mxx, Myy, Mxy, E11, E22, V12, G12)
            % Initialise output
            %{
                BEST_SEQUENCE(1) = Optimum stacking sequence
                BEST_SEQUENCE(2) = Critical value
                BEST_SEQUENCE(3) = Number of permutations
                BEST_SEQUENCE(4) = Analysis time (s)
                BEST_SEQUENCE(5) = Exception
                BEST_SEQUENCE(6) = Best tensor structure
            %}
            BEST_SEQUENCE = cell(1.0, 6.0);

            % Get data from OUTPUT_OPTIMISED
            [enabled, failureCriterion, parameter, objective,...
                thetaAll] = deal(OUTPUT_OPTIMISED{1.0},...
                OUTPUT_OPTIMISED{2.0}, OUTPUT_OPTIMISED{3.0},...
                OUTPUT_OPTIMISED{4.0}, OUTPUT_OPTIMISED{5.0});

            if enabled == false
                % Do not run optimisation if it was disabled by the user
                return
            end

            % Get the stacking permutation matrix
            try
                indexPermutations =...
                    ...
                    fig.combinator(length(thetaAll), nPlies, 'p', 'r');
            catch combiException
                % A problem occurred while getting the combinations
                BEST_SEQUENCE{5.0} = combiException;
                return
            end

            % Get the angles
            anglePermutations = thetaAll(indexPermutations);
            
            % Get the number of permutations
            [nPermutations, ~] = size(anglePermutations);

            % Buffer to store failure assessment values
            CRITERION_BUFFER = zeros(1.0, nPermutations);

            % Set dummy variable
            dummy = zeros(1.0, nPlies);

            % Start the timer
            timer = tic;

            parfor i = 1.0:nPermutations
                % Get the current stacking order
                theta = anglePermutations(i, :);

                % Get the values of theta over the section points
                [~, ~, theta_points, ~, ~, ~, ~, ~, ~, ~] =...
                    ...
                    abd.internal_getSectionPoints(nSectionPoints, '',...
                    nPlies, theta, z, dummy, dummy, dummy, dummy,...
                    tolerance);

                % COMPUTE TRANSFORMED REDUCED STIFFNESS MATRIX COMPONENTS
                [Q11t, Q12t, Q16t, Q22t, Q26t, Q66t] =...
                    ...
                    abd.internal_getTransformedQ(theta, Q11, Q12, Q66, Q22);

                % GET EFFECTIVE THEMAL AND MOISTURE EXPANSION COEFFICIENTS FOR EACH PLY
                [axx, ayy, axy, bxx, byy, bxy] =...
                    ...
                    abd.internal_getThermoHydro(theta_points,...
                    A11_points, A22_points, B11_points, B22_points);

                % COMPUTE A, B and D MATRICES
                [ABD, ABD_INV, Qijt, NxxT, NyyT, NxyT, MxxT, MyyT, MxyT,...
                    NxxM, NyyM, NxyM, MxxM, MyyM, MxyM] =...
                    ...
                    abd.internal_getABD(nPlies, Q11t, Q12t, Q16t, Q22t,...
                    Q26t, Q66t, z, nargin, deltaT, deltaM, axx, ayy,...
                    axy, bxx, byy, bxy, nSectionPoints);

                % COMPUTE TENSOR QUANTITIES
                [~, ~, ~, ~, stress, ~, ~, ~, ~] =...
                    ...
                    abd.internal_getTensor(ABD, Nxx, NxxT, NxxM, Nyy,...
                    NyyT, NyyM, Nxy, NxyT, NxyM, Mxx, MxxT, MxxM, Myy,...
                    MyyT, MyyM, Mxy, MxyT, MxyM, nPlies_points,...
                    z_points, theta_points, Qijt, deltaT, deltaM, axx,...
                    ayy, axy, bxx, byy, bxy, tolerance);

                % PERFORM STRENGTH CALCULATION ON PLY STRESSES
                switch lower(failureCriterion)
                    case 'mstrs'
                        CRITERION =...
                            ...
                            abd.internal_strength.getMstrs(stress, XT,...
                            XC, YT, YC, S);
                    case 'tsaih'
                        CRITERION =...
                            ...
                            abd.internal_strength.getTsaih(parameter,...
                            stress, XT, XC, YT, YC, S);
                    case 'tsaiw'
                        CRITERION =...
                            ...
                            abd.internal_strength.getTsaiw(parameter,...
                            stress, XT, XC, YT, YC, S, C12, B12);
                    case 'azzit'
                        CRITERION =...
                            ...
                            abd.internal_strength.getAzzit(parameter,...
                            nPlies_points, stress, XT, XC, YT, YC, S);
                    case 'mstrn'
                        CRITERION =...
                            ...
                            abd.internal_strength.getMstrn(...
                            nPlies_points, stress, E11, E22, V12, G12,...
                            XET, XEC, YET, YEC, SE);
                    case 'hashin'
                        [HSNFTCRT, HSNFCCRT, HSNMTCRT, HSNMCCRT] =...
                            ...
                            abd.internal_strength.getHashin(...
                            nPlies_points, stress, ALPHA, XHT, XHC, YHT,...
                            YHC, SHX, SHY);

                        % Get the worst criterion of all four calculations
                        CRITERION = max([HSNFTCRT; HSNFCCRT; HSNMTCRT; HSNMCCRT], [], 1.0);
                    otherwise
                        % Default to Tsai-Hill
                        CRITERION =...
                            ...
                            abd.internal_strength.getTsaih(parameter,...
                            stress, XT, XC, YT, YC, S);
                end

                % Get the worst value of CRITERION based on objective
                if objective == 1.0
                    % Objective function: MinMax
                    CRITERION_BUFFER(i) = max(CRITERION);
                else
                    % Objective function: MinMean
                    CRITERION_BUFFER(i) = mean(CRITERION);
                end
            end

            % Stop the timer
            BEST_SEQUENCE{4.0} = toc(timer);

            % Get the permutation with the minimum value of CRITERION
            MIN_CRITERION = find(CRITERION_BUFFER == min(CRITERION_BUFFER), 1.0);

            %{
                Get the stacking sequence corresponding to the optimal
                permutation
            %}
            BEST_SEQUENCE{1.0} = anglePermutations(MIN_CRITERION, :);

            % Save the critical value
            BEST_SEQUENCE{2.0} = CRITERION_BUFFER(MIN_CRITERION);

            % Save number of analysed permutations
            BEST_SEQUENCE{3.0} = nPermutations;

            % Get the optimised stress/strain tensors
            [E_ply_xy, S_ply_xy, E_ply_aligned, S_ply_aligned,...
                symmetricAbd] =...
                ...
                abd.internal_optimise.getOptiStressStrain(...
                BEST_SEQUENCE{1.0}, nSectionPoints, nPlies, z, dummy,...
                tolerance, Q11, Q12, Q66, Q22, A11_points, A22_points,...
                B11_points, B22_points, nargin, deltaT, deltaM, Nxx,...
                Nyy, Nxy, Mxx, Myy, Mxy, nPlies_points, z_points);

            % Collect output from stress/strain analysis
            BEST_SEQUENCE{6.0} = struct('STRESS_XY', S_ply_xy,...
                'STRESS_PLY', S_ply_aligned, 'STRAIN_XY', E_ply_xy,...
                'STRAIN_PLY', E_ply_aligned, 'SYMMETRIC_ABD',...
                symmetricAbd);
        end

        %% GET THE OPTIMISED STRESS/STRAIN TENSORS
        function [E_ply_xy, S_ply_xy, E_ply_aligned, S_ply_aligned,...
                symmetricAbd] = getOptiStressStrain(theta,...
                nSectionPoints, nPlies, z, dummy, tolerance, Q11, Q12,...
                Q66, Q22, A11_points, A22_points, B11_points,...
                B22_points, nargin, deltaT, deltaM, Nxx, Nyy, Nxy, Mxx,...
                Myy, Mxy, nPlies_points, z_points)
            % Get the values of theta over the section points
            [~, ~, theta_points, ~, ~, ~, ~, ~, ~, ~] =...
                ...
                abd.internal_getSectionPoints(nSectionPoints, '',...
                nPlies, theta, z, dummy, dummy, dummy, dummy,...
                tolerance);

            % COMPUTE TRANSFORMED REDUCED STIFFNESS MATRIX COMPONENTS
            [Q11t, Q12t, Q16t, Q22t, Q26t, Q66t] =...
                ...
                abd.internal_getTransformedQ(theta, Q11, Q12, Q66, Q22);

            % GET EFFECTIVE THEMAL AND MOISTURE EXPANSION COEFFICIENTS FOR EACH PLY
            [axx, ayy, axy, bxx, byy, bxy] =...
                ...
                abd.internal_getThermoHydro(theta_points,...
                A11_points, A22_points, B11_points, B22_points);

            % COMPUTE A, B and D MATRICES
            [ABD, ABD_INV, Qijt, NxxT, NyyT, NxyT, MxxT, MyyT, MxyT,...
                NxxM, NyyM, NxyM, MxxM, MyyM, MxyM] =...
                ...
                abd.internal_getABD(nPlies, Q11t, Q12t, Q16t, Q22t,...
                Q26t, Q66t, z, nargin, deltaT, deltaM, axx, ayy,...
                axy, bxx, byy, bxy, nSectionPoints);

            % COMPUTE TENSOR QUANTITIES
            [~, E_ply_xy, S_ply_xy, E_ply_aligned, S_ply_aligned, ~, ~,...
                ~, ~] =...
                ...
                abd.internal_getTensor(ABD, Nxx, NxxT, NxxM, Nyy,...
                NyyT, NyyM, Nxy, NxyT, NxyM, Mxx, MxxT, MxxM, Myy,...
                MyyT, MyyM, Mxy, MxyT, MxyM, nPlies_points,...
                z_points, theta_points, Qijt, deltaT, deltaM, axx,...
                ayy, axy, bxx, byy, bxy, tolerance);

            % DETERMINE IF ABD MATRIX IS SYMMETRIC
            symmetricAbd = abd.internal_getSymmetry(ABD, tolerance);
        end

        %% GET DATA FROM OUTPUT_OPTIMISED
        function [error, output] = getSettings(OUTPUT_OPTIMISED,...
                noFailStress, noFailStrain, noHashin, OUTPUT_STRENGTH)
            % Initialise output
            error = false;
            output = cell(1.0, 4.0);

            if iscell(OUTPUT_OPTIMISED) == false
                OUTPUT_OPTIMISED = {OUTPUT_OPTIMISED};
            end

            if (all(cellfun(@isempty, OUTPUT_OPTIMISED)) == true) ||...
                    (length(OUTPUT_OPTIMISED) ~= 4.0)
                fprintf(['[ABD ERROR] The setting OUTPUT_OPTIMISED req',...
                    'uires four arguments:\n{''<criterion>'', ''<param',...
                    'eter>'', ''<fun>'', theta}\n']);
                error = true;
                return
            end

            % Process the first argument
            argument = OUTPUT_OPTIMISED{1.0};

            % Check validity of the argument
            if isempty(argument) == true
                output{1.0} = false;
            elseif ischar(argument) == false
                % Incorrect argument type
                fprintf(['[ABD ERROR] OUTPUT_OPTIMISED(1) must be a st',...
                    'ring\n']);
                    error = true;
                    return
            elseif ischar(argument) == true
                if (strcmpi(argument, 'mstrs') == false) &&...
                    (strcmpi(argument, 'tsaih') == false) &&...
                    (strcmpi(argument, 'tsaiw') == false) &&...
                    (strcmpi(argument, 'azzit') == false) &&...
                    (strcmpi(argument, 'mstrn') == false) &&...
                    (strcmpi(argument, 'hashin') == false)
                    % Unregognised parameter
                    if (strcmpi(argument, 'hsnftcrt') == true) ||...
                            (strcmpi(argument, 'hsnfccrt') == true) ||...
                            (strcmpi(argument, 'hsnmtcrt') == true) ||...
                            (strcmpi(argument, 'hsnmccrt') == true)
                        fprintf(['[ABD ERROR] Parameter ''HSNFTCRT'', ',...
                            '''HSNFCCRT'', ''HSNMTCRT'' or ''HSNMCCRT',...
                            ''' is\nused for OUTPUT_OPTIMISED(1). Plea',...
                            'se specify ''HASHIN'' instead\n']);
                    else
                        fprintf(['[ABD ERROR] OUTPUT_OPTIMISED(1) must',...
                            ' be one of the following parameters:\nMST',...
                            'RS, TSAIH, TSAIW, AZZIT, MSTRN, HSNFTCRT,',...
                            ' HSNFCCRT, HSNMTCRT or HSNMCCRT\n']);
                    end
                    error = true;
                    return
                elseif (noFailStress == true) &&...
                        (OUTPUT_STRENGTH == true) &&...
                        (strcmpi(argument, 'mstrs') == true ||...
                        strcmpi(argument, 'tsaih') == true ||...
                        strcmpi(argument, 'tsaiw') == true ||...
                        strcmpi(argument, 'azzit') == true)
                    % Insufficient material data
                    fprintf(['[ABD ERROR] Requested a stress-based cri',...
                        'terion for optimisation, but\nFAIL_STRESS pro',...
                        'perties are not available\n']);
                    error = true;
                    return
                elseif (noFailStrain == true) &&...
                        (OUTPUT_STRENGTH == true) &&...
                        (strcmpi(argument, 'mstrn') == true)
                    % Insufficient material data
                    fprintf(['[ABD ERROR] Requested a strain-based cri',...
                        'terion for optimisation, but\nFAIL_STRAIN pro',...
                        'perties are not available\n']);
                    error = true;
                    return
                elseif (noHashin == true) && (OUTPUT_STRENGTH == true) &&...
                        (strcmpi(argument, 'hashin') == true)
                    % Insufficient material data
                    fprintf(['[ABD ERROR] Requested a Hashin criterion',...
                        ' for optimisation, but HASHIN\nproperties are',...
                        ' not available\n']);
                    error = true;
                    return
                else
                    % Everything is OK
                    output{1.0} = true;
                    output{2.0} = argument;
                end
            else
                % Everything is OK
                output{1.0} = true;
                output{2.0} = argument;
            end

            % Process the second argument
            argument = OUTPUT_OPTIMISED{2.0};

            switch lower(argument)
                case 'reserve'
                    output{3.0} = 1.0;
                case 'value'
                    output{3.0} = 2.0;
                otherwise
                    output{3.0} = 1.0;
            end

            % Process the third argument
            argument = OUTPUT_OPTIMISED{3.0};

            switch lower(argument)
                case 'minmax'
                    output{4.0} = 1.0;
                case 'minmean'
                    output{4.0} = 2.0;
                otherwise
                    output{4.0} = 1.0;
            end

            % Process the fourth argument
            argument = OUTPUT_OPTIMISED{4.0};

            if (argument <= 0.0) || (argument > 90.0)
                fprintf(['[ABD ERROR] Invalid value of OUTPUT_OPTIMISE',...
                    'D(4). The angular step size\nmust be in the range',...
                    ' {0 < theta <= 90}\n']);
                error = true;
                return
            else
                output{5.0} = linspace(0.0, 90.0, 1.0 + 90.0/argument);
            end
        end
    end
end
