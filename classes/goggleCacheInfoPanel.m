classdef goggleCacheInfoPanel<handle
    properties(SetAccess=protected)
        parentFig
        position
        gzvm    
        
        mainPanel
        axMeter
        foregroundBlockingPatch
        cacheStatusText
    end
    methods
        function obj=goggleCacheInfoPanel(parentFig, position, gzvm)
            obj.parentFig=parentFig;
            obj.position=position;
            obj.gzvm=gzvm;
            
            obj.mainPanel=uipanel(...
                'Parent', parentFig, ...
                'Units', 'normalized', ...
                'Position', position, ...
                'BackgroundColor', gbSetting('viewer.panelBkgdColor'), ...
                'ButtonDownFcn', {@changeCacheSize, obj});
            obj.axMeter=axes(...
                'Parent', obj.mainPanel, ...
                'Position', [0.02 0.42 0.96 0.3], ...
                'Units', 'normalized', ...
                'Visible', 'on', ...
                'XTick', [], 'YTick', [], ...
                'Box', 'on', ...
                'XLim', [0 1], 'YLim', [0 1], ...
                'HitTest', 'off');
            uicontrol(...
                'Parent', obj.mainPanel, ...
                'Style', 'text', ...
                'Units', 'normalized', ...
                'Position', [0.02 0.8 0.96 0.15], ...
                'FontSize',gbSetting('font.size'), ...
                'FontName', gbSetting('font.name'), ...
                'FontWeight', 'bold', ...
                'String', 'Zoomed View Cache Usage:', ...
                'HorizontalAlignment', 'center', ...
                'BackgroundColor', gbSetting('viewer.panelBkgdColor'), ...
                'ForegroundColor', gbSetting('viewer.textMainColor'), ...
                'HitTest', 'off');
            
            drawBackgroundPatch(obj.axMeter);
            obj.foregroundBlockingPatch=rectangle(...
                'Parent', obj.axMeter, ...
                'Position', [0.2 0 0.8 1], ...
                'EdgeColor', 'none', ...
                'FaceColor', gbSetting('viewer.mainBkgdColor'), ...
                'HitTest', 'off');
            
            obj.cacheStatusText=uicontrol(...
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
            obj.updateCacheStatusDisplay();
        end
    end
    methods
        function updateCacheStatusDisplay(obj)
            cacheLimit=gbSetting('cache.sizeLimitMiB');
            cacheUsed=obj.gzvm.cacheMemoryUsed;
            fracUsed=cacheUsed/cacheLimit;
            obj.cacheStatusText.String=sprintf('%u/%uMiB (%u%%) in use', round(cacheUsed), cacheLimit, round(fracUsed*100));
            obj.foregroundBlockingPatch.Position=[fracUsed, 0, 1-fracUsed, 1];
        end
    end
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

function changeCacheSize(~,~, obj)
    persistent waitFlag
    if isempty(waitFlag)
        waitFlag=1; %#ok<NASGU>
        pause(0.2)
        waitFlag=[];
    else
        oldLim=gbSetting('cache.sizeLimitMiB');
        newLim=inputdlg('New Cache Size (MiB)', 'Change Cache Limit', 1, {num2str(oldLim)});
        if ~isempty(newLim)&&~isempty(str2double(newLim))&&~isnan(str2double(newLim))
            if checkCacheSizeOK(obj, str2double(newLim))
                gbSetting('cache.sizeLimitMiB', str2double(newLim))
                if str2double(newLim)<oldLim
                    obj.gzvm.cleanUpCache;
                end
            end
        end
        obj.updateCacheStatusDisplay();
    end
end

function flag=checkCacheSizeOK(obj, newLim)

    [freeMemKiB, totalMemKiB]=systemMemStats;
    freeMemMiB=freeMemKiB/1024;
    totalMemMiB=totalMemKiB/1024;
    usedMemMiB=totalMemMiB-freeMemMiB;

    
    totalNewMemoryUsageMiB=newLim+usedMemMiB-obj.gzvm.cacheMemoryUsed;
    
    if totalNewMemoryUsageMiB>totalMemMiB;
        response=questdlg(sprintf('Specified cache size (%uMiB)\nwould exceed available memory.\nAre you sure you want to do this?', round(newLim)), ...
            'Confirm memory change', 'Yes', 'No', 'No');
        if ~isempty(response)&&strcmp(response, 'Yes')
            flag=1;
        else
            flag=0;
        end
    else
        flag=1;
    end
end











