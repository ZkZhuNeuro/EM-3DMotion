function simulation_GLM()
% Interactive demo: b2 controls stim intercept shift, b3 controls stim slope change
% Non-stim: logit(p) = b0 + b1*coh
% Stim:     logit(p) = (b0+b2) + (b1+b3)*coh

    % ----- Settings -----
    coh = linspace(-1, 1, 400)';          % x-axis for smooth curves
    sigmoid = @(x) 1 ./ (1 + exp(-x));

    % Initial parameters
    b0 = 0;
    b1 = 4;
    b2 = 0;
    b3 = 0;

    % ----- UI -----
    fig = uifigure('Name','Psychometric demo: b2=intercept shift, b3=slope change',...
        'Position',[100 100 950 520]);

    ax = uiaxes(fig,'Position',[40 130 560 360]);
    grid(ax,'on');
    ax.YLim = [0 1];
    ax.XLim = [min(coh) max(coh)];
    xlabel(ax,'Coherence');
    ylabel(ax,'P(towards)');

    % Labels panel
    infoPanel = uipanel(fig,'Title','Parameters / Interpretation',...
        'Position',[620 130 300 360]);

    lblModel = uilabel(infoPanel,'Position',[10 300 280 50],...
        'Text',sprintf(['Non-stim: logit(p)=b0 + b1*coh\n',...
                        'Stim:     logit(p)=(b0+b2) + (b1+b3)*coh']));

    lblB = uilabel(infoPanel,'Position',[10 240 280 50],'Text','');
    lblPSE = uilabel(infoPanel,'Position',[10 190 280 40],'Text','');
    lblSlope = uilabel(infoPanel,'Position',[10 150 280 40],'Text','');
    lblNote = uilabel(infoPanel,'Position',[10 20 280 120],...
        'Text',sprintf(['Notes:\n',...
        '- b2 shifts ONLY the stim intercept (log-odds offset).\n',...
        '- b3 changes ONLY the stim slope w.r.t. coherence.\n',...
        '- PSE (50%% point) for logistic: coh50 = -intercept/slope.\n',...
        '- Slope at coh=0: p''(0)=0.25*slope (when intercept=0).']));

    % Sliders + labels
    % b0
    uilabel(fig,'Position',[40 90 60 20],'Text','b0');
    sld_b0 = uislider(fig,'Position',[90 100 500 3],...
        'Limits',[-6 6],'Value',b0);

    % b1
    uilabel(fig,'Position',[40 65 60 20],'Text','b1');
    sld_b1 = uislider(fig,'Position',[90 75 500 3],...
        'Limits',[-12 12],'Value',b1);

    % b2 (stim intercept shift)
    uilabel(fig,'Position',[40 40 60 20],'Text','b2');
    sld_b2 = uislider(fig,'Position',[90 50 500 3],...
        'Limits',[-6 6],'Value',b2);

    % b3 (stim slope change)
    uilabel(fig,'Position',[40 15 60 20],'Text','b3');
    sld_b3 = uislider(fig,'Position',[90 25 500 3],...
        'Limits',[-12 12],'Value',b3);

    % Plot handles
    hold(ax,'on');
    hNon = plot(ax, coh, nan(size(coh)),'LineWidth',2);
    hStim = plot(ax, coh, nan(size(coh)),'LineWidth',2);
    legend(ax,{'Non-stim','Stim'},'Location','southeast');

    % Callback wiring
    sld_b0.ValueChangingFcn = @(src,evt) updatePlot(evt.Value, sld_b1.Value, sld_b2.Value, sld_b3.Value);
    sld_b1.ValueChangingFcn = @(src,evt) updatePlot(sld_b0.Value, evt.Value, sld_b2.Value, sld_b3.Value);
    sld_b2.ValueChangingFcn = @(src,evt) updatePlot(sld_b0.Value, sld_b1.Value, evt.Value, sld_b3.Value);
    sld_b3.ValueChangingFcn = @(src,evt) updatePlot(sld_b0.Value, sld_b1.Value, sld_b2.Value, evt.Value);

    % Initial draw
    updatePlot(b0,b1,b2,b3);

    % ----- Nested updater -----
    function updatePlot(b0_now,b1_now,b2_now,b3_now)
        % Curves
        eta_non  = b0_now + b1_now*coh;
        eta_stim = (b0_now + b2_now) + (b1_now + b3_now)*coh;

        p_non  = sigmoid(eta_non);
        p_stim = sigmoid(eta_stim);

        hNon.YData  = p_non;
        hStim.YData = p_stim;

        % Display parameters (the "corresponding b2 and b3" are literally the sliders)
        lblB.Text = sprintf('Current:\n b0=%.3f, b1=%.3f\n b2=%.3f (stim intercept shift)\n b3=%.3f (stim slope change)',...
            b0_now,b1_now,b2_now,b3_now);

        % PSE (50% point): solve eta=0 => coh50 = -intercept/slope
        % Non-stim intercept = b0, slope = b1
        % Stim intercept = b0+b2, slope = b1+b3
        coh50_non = safeDivide(-b0_now, b1_now);
        coh50_stm = safeDivide(-(b0_now+b2_now), (b1_now+b3_now));

        lblPSE.Text = sprintf('PSE (coh at p=0.5):\n non-stim: %.3f\n stim:     %.3f', coh50_non, coh50_stm);

        % "Sensitivity" proxy: absolute slope parameter
        lblSlope.Text = sprintf('Slope parameter (|d logit / d coh|):\n non-stim: %.3f\n stim:     %.3f', abs(b1_now), abs(b1_now+b3_now));

        title(ax, sprintf('Non-stim: logit(p)=%.2f + %.2f*coh   |   Stim: logit(p)=%.2f + %.2f*coh',...
            b0_now, b1_now, (b0_now+b2_now), (b1_now+b3_now)));
        drawnow limitrate;
    end

    function out = safeDivide(a,b)
        if abs(b) < 1e-9
            out = NaN;
        else
            out = a/b;
        end
    end
end