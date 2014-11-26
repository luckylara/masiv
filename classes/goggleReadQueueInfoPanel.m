classdef goggleReadQueueInfoPanel<handle
    properties(SetAccess=protected)
        parentFig
        position
        gzvm    
                
        mainPanel
        axMeter
        foregroundBlockingPatch
        readQueueSizeText
        tmr
    end
    methods
        function obj=goggleReadQueueInfoPanel(parentFig, position, gzvm)
            obj.parentFig=parentFig;
            obj.position=position;
            obj.gzvm=gzvm;
            
            obj.mainPanel=uipanel(...
                'Parent', parentFig, ...
                'Units', 'normalized', ...
                'Position', position, ...
                'BackgroundColor', gbSetting('viewer.panelBkgdColor'), ...
                'ButtonDownFcn', @changeMax);
            uicontrol(...
                'Parent', obj.mainPanel, ...
                'Style', 'text', ...
                'Units', 'normalized', ...
                'Position', [0.02 0.8 0.96 0.15], ...
                'FontSize',gbSetting('font.size'), ...
                'FontName', gbSetting('font.name'), ...
                'FontWeight', 'bold', ...
                'String', 'Read Queue Size:', ...
                'HorizontalAlignment', 'center', ...
                'BackgroundColor', gbSetting('viewer.panelBkgdColor'), ...
                'ForegroundColor', gbSetting('viewer.textMainColor'), ...
                'HitTest', 'off');
            
             obj.axMeter=axes(...
                'Parent', obj.mainPanel, ...
                'Position', [0.02 0.42 0.96 0.3], ...
                'Units', 'normalized', ...
                'Visible', 'on', ...
                'XTick', [], 'YTick', [], ...
                'Box', 'on', ...
                'XLim', [0 1], 'YLim', [0 1], ...
                'HitTest', 'off');
            drawBackgroundPatch(obj.axMeter);
            obj.foregroundBlockingPatch=rectangle(...
                'Parent', obj.axMeter, ...
                'Position', [0.2 0 0.8 1], ...
                'EdgeColor', 'none', ...
                'FaceColor', gbSetting('viewer.mainBkgdColor'), ...
                'HitTest', 'off');
            
            obj.readQueueSizeText=uicontrol(...
                'Parent', obj.mainPanel, ...
                'Style', 'text', ...
                'Units', 'normalized', ...
                'Position', [0.02 0.1 0.96 0.15], ...
                'FontSize',gbSetting('font.size'), ...
                'FontName', gbSetting('font.name'), ...
                'HorizontalAlignment', 'center', ...
                'BackgroundColor', gbSetting('viewer.panelBkgdColor'), ...
                'ForegroundColor', gbSetting('viewer.textMainColor'), ...
                'HitTest', 'off');
           obj.tmr=timer('ExecutionMode', 'fixedSpacing', 'Period', 0.05, 'TimerFcn', {@updateNumberOfReadsInQueue, obj});
           start(obj.tmr)
           
        end
        function delete(obj)
            stop(obj.tmr)
            deleteReadQueueFile
        end
    end
end

function updateNumberOfReadsInQueue(~,~, obj)
    n=getReadQueueSize;
    obj.readQueueSizeText.String=num2str(n);
    frac=n/gbSetting('readQueueInfoPanel.max');
    obj.foregroundBlockingPatch.Position=[frac, 0, 1-frac, 1];
end

function drawBackgroundPatch(hAx)
    x=[0 0.5 1 1 0.5 0];
    y=[0 0  0   1   1   1];
    red=hsv2rgb([0 0.8 0.8]);
    green=hsv2rgb([0.4 0.8 0.8]);
    yellow=hsv2rgb([0.1 0.8 0.8]);
    c=[green;yellow;red;red;yellow;green];
    patch('Parent', hAx, 'Faces', [1 2 3 4 5 6], 'Vertices', [x; y]', 'EdgeColor', 'none',...
        'FaceVertexCData',c,'FaceColor', 'interp', 'HitTest', 'off');
end


function changeMax(~,~)
    persistent waitFlag
    if isempty(waitFlag)
        waitFlag=1; %#ok<NASGU>
        pause(0.2)
        waitFlag=[];
    else
        oldMax=gbSetting('readQueueInfoPanel.max');
        newMax=inputdlg('Enter new max for read meter', 'Change Display Limit', 1, {num2str(oldMax)});
        if ~isempty(newLim)&&~isempty(str2double(newLim))
            gbSetting('readQueueInfoPanel.max', str2double(newMax))
        end
    end
end