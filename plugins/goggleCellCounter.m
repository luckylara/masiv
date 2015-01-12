classdef goggleCellCounter<goggleBoxPlugin
    properties
        goggleViewer
        hFig
        
        cursorListenerInsideAxes
        cursorListenerOutsideAxes
        cursorListenerClick
        keyPressListener
        
        hMarkerButtonGroup
        hMarkerTypeSelection
        hMarkerTypeChangeNameButtons
        hColorIndicatorPanel
        hCountIndicatorAx
        hCountIndicatorText
        
        hModeButtonGroup
        hModeAdd
        hModeDelete
        
        cursorX
        cursorY
        
        markerTypes
        markers
        hDisplayedMarkers
        hDisplayedMarkerHighlights
        
        fontName
        fontSize
        
        scrolledListener
        zoomedListener
        
        changeFlag=0
        
    end
    
    properties(Dependent, SetAccess=protected)
        currentType
        cursorZVoxels
        cursorZUnits
        
        correctionOffset
        deCorrectedCursorX
        deCorrectedCursorY
    end
    
    methods
        %% Constructor
        function obj=goggleCellCounter(caller, ~)
            obj=obj@goggleBoxPlugin;
            obj.goggleViewer=caller.UserData;
            
            %% Settings
            obj.fontName=gbSetting('font.name');
            obj.fontSize=gbSetting('font.size');
            try
                pos=gbSetting('cellCounter.figurePosition');
            catch
                ssz=get(0, 'ScreenSize');
                lb=[ssz(3)/3 ssz(4)/3];
                pos=round([lb 400 550]);
                gbSetting('cellCounter.figurePosition', pos)
                gbSetting('cellCounter.markerDiameter.xy', 20);
                gbSetting('cellCounter.markerDiameter.z', 30);
                gbSetting('cellCounter.minimumSize', 20)
                gbSetting('cellCounter.maximumDistanceVoxelsForDeletion', 500)
            end
            gbSetting('cellCounter.importExportDefault', gbSetting('defaultDirectory'))

            %% Main UI initialisation
            obj.hFig=figure(...
                'Position', pos, ...
                'CloseRequestFcn', {@deleteFig, obj}, ...
                'MenuBar', 'none', ...
                'NumberTitle', 'off', ...
                'Name', ['Cell Counter: ' obj.goggleViewer.mosaicInfo.experimentName], ...
                'Color', gbSetting('viewer.panelBkgdColor'), ...
                'KeyPressFcn', {@keyPress, obj});
            
            %% Marker selection initialisation
            obj.hMarkerButtonGroup=uibuttongroup(...
                'Parent', obj.hFig, ...
                'Units', 'normalized', ...
                'Position', [0.02 0.02 0.6 0.96], ...
                'BackgroundColor', gbSetting('viewer.mainBkgdColor'), ...
                'ForegroundColor', gbSetting('viewer.textMainColor'), ...
                'Title', 'Marker Type', ...
                'FontName', obj.fontName, ...
                'FontSize', obj.fontSize);
            obj.markerTypes=defaultMarkerTypes(10);
            updateMarkerTypeUISelections(obj);
            
            %% Mode selection initialisation
            obj.hModeButtonGroup=uibuttongroup(...
                'Parent', obj.hFig, ...
                'Units', 'normalized', ...
                'Position', [0.64 0.86 0.34 0.12], ...
                'BackgroundColor', gbSetting('viewer.mainBkgdColor'), ...
                'ForegroundColor', gbSetting('viewer.textMainColor'), ...
                'Title', 'Placement Mode', ...
                'FontName', obj.fontName, ...
                'FontSize', obj.fontSize);
            obj.hModeAdd=uicontrol(...
                'Parent', obj.hModeButtonGroup, ...
                'Style', 'radiobutton', ...
                'Units', 'normalized', ...
                'Position', [0.05 0.51 0.96 0.47], ...
                'String', 'Add (ctrl+a)', ...
                'FontName', obj.fontName, ...
                'FontSize', obj.fontSize, ...
                'Value', 1, ...
                'BackgroundColor', gbSetting('viewer.mainBkgdColor'), ...
                'ForegroundColor', gbSetting('viewer.textMainColor'));
            obj.hModeDelete=uicontrol(...
                'Parent', obj.hModeButtonGroup, ...
                'Style', 'radiobutton', ...
                'Units', 'normalized', ...
                'Position', [0.05 0.02 0.96 0.47], ...
                'String', 'Delete (ctrl+d)', ...
                'FontName', obj.fontName, ...
                'FontSize', obj.fontSize, ...
                'Value', 0, ...
                'BackgroundColor', gbSetting('viewer.mainBkgdColor'), ...
                'ForegroundColor', gbSetting('viewer.textMainColor'));
            
            %% Settings panel
            hSettingPanel=uipanel(...
                'Parent', obj.hFig, ...
                'Units', 'normalized', ...
                'Position', [0.64 0.17 0.34 0.67], ...
                'BackgroundColor', gbSetting('viewer.mainBkgdColor'), ...
                'ForegroundColor', gbSetting('viewer.textMainColor'), ...
                'Title', 'Display Settings', ...
                'FontName', obj.fontName, ...
                'FontSize', obj.fontSize);
            setUpSettingBox('XY Size', 'cellCounter.markerDiameter.xy', 0.8, hSettingPanel, obj)
            setUpSettingBox('Z Size', 'cellCounter.markerDiameter.z', 0.7, hSettingPanel, obj)
            setUpSettingBox('Min. Size', 'cellCounter.minimumSize', 0.6, hSettingPanel, obj)
            setUpSettingBox('Delete Prox.', 'cellCounter.maximumDistanceVoxelsForDeletion', 0.48, hSettingPanel, obj)

            %% Import / Export data
           
            uicontrol(...
                'Parent', obj.hFig, ...
                'Style', 'pushbutton', ...
                'Units', 'normalized', ...
                'Position', [0.64 0.09 0.34 0.06], ...
                'String', 'Import...', ...
                'FontName', obj.fontName, ...
                'FontSize', obj.fontSize, ...
                'Value', 1, ...
                'BackgroundColor', gbSetting('viewer.mainBkgdColor'), ...
                'ForegroundColor', gbSetting('viewer.textMainColor'), ...
                'Callback', {@importData, obj});
            uicontrol(...
                'Parent', obj.hFig, ...
                'Style', 'pushbutton', ...
                'Units', 'normalized', ...
                'Position', [0.64 0.02 0.34 0.06], ...
                'String', 'Export...', ...
                'FontName', obj.fontName, ...
                'FontSize', obj.fontSize, ...
                'Value', 0, ...
                'BackgroundColor', gbSetting('viewer.mainBkgdColor'), ...
                'ForegroundColor', gbSetting('viewer.textMainColor'), ...
                'Callback', {@exportData, obj});
            
            %% Listener Declarations
            obj.cursorListenerInsideAxes=event.listener(obj.goggleViewer, 'CursorPositionChangedWithinImageAxes', @obj.updateCursorWithinAxes);
            obj.cursorListenerOutsideAxes=event.listener(obj.goggleViewer, 'CursorPositionChangedOutsideImageAxes', @obj.updateCursorOutsideAxes);
            obj.cursorListenerClick=event.listener(obj.goggleViewer, 'ViewClicked', @obj.mouseClickInMainWindowAxes);
            obj.scrolledListener=event.listener(obj.goggleViewer, 'Scrolled', @obj.drawMarkers);
            obj.zoomedListener=event.listener(obj.goggleViewer, 'Zoomed', @obj.drawMarkers);
            obj.keyPressListener=event.listener(obj.goggleViewer, 'KeyPress', @obj.parentKeyPress);
            
            %% Freeze menu
            obj.setParentMenuEnabled('off')            
            
        end
        
        %% Set up markers
        function updateMarkerTypeUISelections(obj)
            %% Clear controls, if appropriate
            if ~isempty(obj.hMarkerTypeSelection)
                prevSelection=find(obj.hMarkerTypeSelection==obj.hMarkerButtonGroup.SelectedObject);
                delete(obj.hMarkerTypeSelection)
                delete(obj.hMarkerTypeChangeNameButtons)
                delete(obj.hCountIndicatorAx)
            else
                prevSelection=1;
            end
            
            %% Set up radio buttons
            ii=1;
            
            obj.hMarkerTypeSelection=uicontrol(...
                'Parent', obj.hMarkerButtonGroup, ...
                'Style', 'radiobutton', ...
                'Units', 'normalized', ...
                'Position', [0.18 0.98-(0.08*ii) 0.45 0.08], ...
                'String', obj.markerTypes(ii).name, ...
                'UserData', ii, ...
                'FontName', obj.fontName, ...
                'FontSize', obj.fontSize, ...
                'BackgroundColor', gbSetting('viewer.mainBkgdColor'), ...
                'ForegroundColor', gbSetting('viewer.textMainColor'));
            setNameChangeContextMenu(obj.hMarkerTypeSelection, obj)
            
            for ii=2:numel(obj.markerTypes)
                obj.hMarkerTypeSelection(ii)=uicontrol(...
                    'Parent', obj.hMarkerButtonGroup, ...
                    'Style', 'radiobutton', ...
                    'Units', 'normalized', ...
                    'Position', [0.18 0.98-(0.08*ii) 0.45 0.08], ...
                    'String', obj.markerTypes(ii).name, ...
                    'UserData', ii, ...
                    'FontName', obj.fontName, ...
                    'FontSize', obj.fontSize, ...
                    'BackgroundColor', gbSetting('viewer.mainBkgdColor'), ...
                    'ForegroundColor', gbSetting('viewer.textMainColor'));
                setNameChangeContextMenu(obj.hMarkerTypeSelection(ii), obj)
                
            end
            obj.hMarkerTypeSelection(1).Value=1;
            
            %% Set up color indicator
            ii=1;
            obj.hColorIndicatorPanel=uipanel(...
                'Parent', obj.hMarkerButtonGroup, ...
                'Units', 'normalized', ...
                'Position', [0.02 0.98-(0.08*ii)+0.01 0.12 0.06], ...
                'UserData', ii, ...
                'FontName', obj.fontName, ...
                'FontSize', obj.fontSize-1, ...
                'BackgroundColor', obj.markerTypes(ii).color);
            setColorChangeContextMenu(obj.hColorIndicatorPanel, obj);
            for ii=2:numel(obj.markerTypes)
                obj.hColorIndicatorPanel(ii)=uipanel(...
                    'Parent', obj.hMarkerButtonGroup, ...
                    'Units', 'normalized', ...
                    'Position', [0.02 0.98-(0.08*ii)+0.01 0.12 0.06], ...
                    'UserData', ii, ...
                    'FontName', obj.fontName, ...
                    'FontSize', obj.fontSize-1, ...
                    'BackgroundColor', obj.markerTypes(ii).color);
                setColorChangeContextMenu(obj.hColorIndicatorPanel(ii), obj);
            end
            
            %% Set up count indicator
            ii=1;
            obj.hCountIndicatorAx=axes(...
                'Parent', obj.hMarkerButtonGroup, ...
                'Units', 'normalized', ...
                'Position', [0.65 0 0.3 1], ...
                'Visible', 'off');
            obj.hCountIndicatorText=text(...
                'Parent', obj.hCountIndicatorAx, ...
                'Units', 'normalized', ...
                'Position', [0.5 0.98-(0.08*ii)+0.04], ...
                'String', '0', ...
                'UserData', ii, ...
                'FontName', obj.fontName, ...
                'FontSize', obj.fontSize+2, ...
                'Color', gbSetting('viewer.textMainColor'), ...
                'HorizontalAlignment', 'center');
            
            obj.hMarkerTypeSelection(ii).Value=1;
            obj.updateMarkerCount(obj.currentType);
            
            for ii=2:numel(obj.markerTypes)
                obj.hCountIndicatorText(ii)=text(...
                    'Parent', obj.hCountIndicatorAx, ...
                    'Units', 'normalized', ...
                    'Position', [0.5 0.98-(0.08*ii)+0.04], ...
                    'String', '0', ...
                    'UserData', ii, ...
                    'FontName', obj.fontName, ...
                    'FontSize', obj.fontSize+2, ...
                    'Color', gbSetting('viewer.textMainColor'), ...
                    'HorizontalAlignment', 'center');
                obj.hMarkerTypeSelection(ii).Value=1;
                obj.updateMarkerCount(obj.currentType);
                
            end
            
            %% Reset Selection
            obj.hMarkerTypeSelection(prevSelection).Value=1;
            
        end
        
        %% Listener Callbacks
        function updateCursorWithinAxes(obj, ~, evData)
            obj.cursorX=round(evData.CursorPosition(1,1));
            obj.cursorY=round(evData.CursorPosition(2,2));
            obj.goggleViewer.hFig.Pointer='crosshair';
        end
        function updateCursorOutsideAxes(obj, ~, ~)
            obj.goggleViewer.hFig.Pointer='arrow';
        end
        function mouseClickInMainWindowAxes(obj, ~, ~)
            if obj.hModeAdd.Value
                obj.UIaddMarker
            elseif obj.hModeDelete.Value
                obj.UIdeleteMarker
            else
                error('Unknown mode selection')
            end
            
        end
        function parentKeyPress(obj, ~,ev)
            keyPress([], ev.KeyPressData, obj);
        end
        
        %% Functions
        function UIaddMarker(obj)
            newMarker=goggleMarker(obj.currentType, obj.deCorrectedCursorX, obj.deCorrectedCursorY, obj.cursorZVoxels);
            if isempty(obj.markers)
                obj.markers=newMarker;
            else
                obj.markers=[obj.markers newMarker];
            end
            drawMarkers(obj)
            %% Update count
            obj.updateMarkerCount(obj.currentType);
            %% Set change flag
            obj.changeFlag=1;
        end
        
        function UIdeleteMarker(obj)
            if isempty(obj.markers)
                return
            end
            matchIdx=find([obj.markers.type]==obj.currentType&[obj.markers.zVoxel]==obj.cursorZVoxels);
            
            if ~isempty(matchIdx)
                markersOfCurrentType=obj.markers(matchIdx);
                
                [dist, closestIdx]=minEucDist2DToMarker(markersOfCurrentType, obj);
                
                if dist<gbSetting('cellCounter.maximumDistanceVoxelsForDeletion')
                    idxToDelete=matchIdx(closestIdx);
                    obj.markers(idxToDelete)=[];
                    obj.drawMarkers;
                end
            end
            %% Update count
            obj.updateMarkerCount(obj.currentType);
            %% Set change flag
            obj.changeFlag=1;
        end
        
        function drawMarkers(obj, ~, ~)
            obj.clearMarkers;
            %% Calculate position and size
            zRadius=(gbSetting('cellCounter.markerDiameter.z')/2);
            
            allMarkerZVoxel=[obj.markers.zVoxel];
            
            allMarkerZRelativeToCurrentPlaneVoxels=(abs(allMarkerZVoxel-obj.cursorZVoxels));
            
            idx=allMarkerZRelativeToCurrentPlaneVoxels<zRadius;
            if ~any(idx)
                return
            end
            markersWithinViewOfThisPlane=obj.markers(idx);
            
            markerX=[markersWithinViewOfThisPlane.xVoxel];
            markerY=[markersWithinViewOfThisPlane.yVoxel];
            markerZ=[markersWithinViewOfThisPlane.zVoxel];
            
            [markerX, markerY]=correctXY(obj, markerX, markerY, markerZ);
            
            markerRelZ=allMarkerZRelativeToCurrentPlaneVoxels(idx);
            markerSz=(gbSetting('cellCounter.markerDiameter.xy')*(1-markerRelZ/zRadius)*obj.goggleViewer.mainDisplay.viewPixelSizeOriginalVoxels).^2;
            
            markerSz=max(markerSz, gbSetting('cellCounter.minimumSize'));
            
            markerCol=cat(1, markersWithinViewOfThisPlane.color);
            
            hImgAx=obj.goggleViewer.hImgAx;
            prevhold=ishold(hImgAx);
            hold(hImgAx, 'on')
            %% Draw
            obj.hDisplayedMarkers=scatter(obj.goggleViewer.hImgAx, markerX , markerY, markerSz, markerCol, 'filled', 'HitTest', 'off');
            %% Draw highlights on this plane if we're not too zoomed out
            
            obj.drawMarkerHighlights;
            
            %% Restore hold
            if ~prevhold
                hold(hImgAx, 'off')
            end
        end
        
        function drawMarkerHighlights(obj)
            allMarkerZVoxel=[obj.markers.zVoxel];
            allMarkerZRelativeToCurrentPlaneUnits=(abs(allMarkerZVoxel-obj.cursorZVoxels));
            %% Draw spots within markers in this plane
            markerInThisPlaneIdx=allMarkerZRelativeToCurrentPlaneUnits==0;
            markersInThisPlane=obj.markers(markerInThisPlaneIdx);
            
            markerX=[markersInThisPlane.xVoxel];
            markerY=[markersInThisPlane.yVoxel];
            markerZ=[markersInThisPlane.zVoxel];

            if~isempty(markerX)
                [markerX, markerY]=correctXY(obj, markerX, markerY, markerZ);
            end
            markerSz=(gbSetting('cellCounter.markerDiameter.xy')*obj.goggleViewer.mainDisplay.viewPixelSizeOriginalVoxels)^2;
            
            if markerSz>=gbSetting('cellCounter.minimumSize')
                obj.hDisplayedMarkerHighlights=scatter(obj.goggleViewer.hImgAx, markerX , markerY, markerSz/4, [1 1 1], 'filled', 'HitTest', 'off');
            end
        end
        
        function clearMarkers(obj)
            if ~isempty(obj.hDisplayedMarkers)
                delete(obj.hDisplayedMarkers)
            end
            if ~isempty(obj.hDisplayedMarkerHighlights)
                delete(obj.hDisplayedMarkerHighlights)
            end
        end
        
        function updateMarkerCount(obj, markerTypeToUpdate)
            if isempty(obj.markers)
                num=0;
            else
                num=sum([obj.markers.type]==markerTypeToUpdate);
            end
            idx=obj.markerTypes==markerTypeToUpdate;
            
            obj.hCountIndicatorText(idx).String=sprintf('%u', num);
        end
        
        function setParentMenuEnabled(obj, val)
            obj.goggleViewer.mnuPlugins.Enable=val;
        end
        
        %% Getters
        function type=get.currentType(obj)
            type=obj.markerTypes(obj.hMarkerButtonGroup.SelectedObject.UserData);
        end
        function z=get.cursorZVoxels(obj)
            z=obj.goggleViewer.mainDisplay.currentZPlaneOriginalVoxels;
        end
        function z=get.cursorZUnits(obj)
            z=obj.goggleViewer.mainDisplay.currentZPlaneUnits;
        end
        
        function offset=get.correctionOffset(obj)
            zvm=obj.goggleViewer.mainDisplay.zoomedViewManager;
            if isempty(zvm.xyPositionAdjustProfile)
                offset=[0 0];
            else
                offset=zvm.xyPositionAdjustProfile(obj.cursorZVoxels, :);
            end
        end
        function x=get.deCorrectedCursorX(obj)
            x=obj.cursorX-obj.correctionOffset(2);
        end
        function y=get.deCorrectedCursorY(obj)
             y=obj.cursorY-obj.correctionOffset(1);
        end
    end
    
    methods(Static)
        function d=displayString()
            d='Cell Counter...';
        end
    end
end

%% Callbacks

function deleteFig(~, ~, obj)
    if obj.changeFlag
        agree=questdlg(sprintf('There are unsaved changes that will be lost.\nAre you sure you want to end this session?'), 'Cell Counter', 'Yes', 'No', 'Yes');
        if strcmp(agree, 'No')
            return
        end
    end
    obj.clearMarkers;
    obj.goggleViewer.hFig.Pointer='arrow';
    obj.setParentMenuEnabled('on')
    delete(obj.hFig);
    delete(obj);
end

function exportData(~, ~, obj)
    [f,p]=uiputfile('*.yml', 'Export Markers', gbSetting('cellCounter.importExportDefault'));
    if isnumeric(f)&&f==0
        return
    end
    
    s=struct;
    for ii=1:numel(obj.markerTypes)
        thisType=obj.markerTypes(ii);
        s.(thisType.name).color=thisType.color;
        if~isempty(obj.markers)
            markersOfThisType=obj.markers([obj.markers.type]==thisType);
            if ~isempty(markersOfThisType)
                s.(thisType.name).markers=markersOfThisType.toStructArray;
            end
        end
    end
    try
        writeSimpleYAML(s, fullfile(p, f))
    catch err
        errordlg('YAML file could not be created', 'Cell Counter')
        rethrow(err)
    end
    
    obj.changeFlag=0;
    
    gbSetting('cellCounter.importExportDefault', fullfile(p, f))
    %% Read it back in to check it's OK
    try
        s=readSimpleYAML(fullfile(p,f));
        [m,t]=convertStructArrayToMarkerAndTypeArrays(s);
        if any(sort(m)~=sort(obj.markers))||any(sort(t)~=sort(obj.markerTypes))
            error('YAML file validation failed')
        else
            msgbox(sprintf('YAML file successfully exported to\n%s\nand validated', fullfile(p, f)))
        end
    catch err
        errordlg(sprintf('Export does not appear to have been successful.\nYAML file seems corrupted, or could not be verified'), 'Cell Counter')
        rethrow(err)
    end
end

function importData(~, ~, obj)
     if obj.changeFlag
        agree=questdlg(sprintf('There are unsaved changes that will be lost.\nAre you sure you want to import markers?'), 'Cell Counter', 'Yes', 'No', 'Yes');
        if strcmp(agree, 'No')
            return
        end
     end
    [f,p]=uigetfile('*.yml', 'Import Markers', gbSetting('cellCounter.importExportDefault'));
    
    try
        s=readSimpleYAML(fullfile(p, f));
    catch
        errordlg('Import error', 'Cell Counter')
        rethrow(err)
    end
    [m,t]=convertStructArrayToMarkerAndTypeArrays(s);
    obj.markerTypes=t;
    obj.markers=m;
    obj.updateMarkerTypeUISelections();
    obj.drawMarkers();
end

%% Utilities
function ms=defaultMarkerTypes(nTypes)
ms(nTypes)=goggleMarkerType;
cols=lines(nTypes);
for ii=1:nTypes
    ms(ii).name=sprintf('Type%u', ii);
    ms(ii).color=cols(ii, :);
end
end

function [dist, idx]=minEucDist2DToMarker(markerCollection, obj)
mX=[markerCollection.xVoxel];
mY=[markerCollection.yVoxel];

x=obj.deCorrectedCursorX;
y=obj.deCorrectedCursorY;

euclideanDistance=sqrt((mX-x).^2+(mY-y).^2);
[dist, idx]=min(euclideanDistance);
end

function keyPress(~, eventdata, obj)
key=eventdata.Key;
key=strrep(key, 'numpad', '');

ctrlMod=ismember('control', eventdata.Modifier);

switch key
    case {'1' '2' '3' '4' '5' '6' '7' '8' '9'}
        obj.hMarkerTypeSelection(str2double(key)).Value=1;
    case {'0'}
        obj.hMarkerTypeSelection(10).Value=1;
    case 'a'
        if ctrlMod
            obj.hModeAdd.Value=1;
        end
    case 'd'
        if ctrlMod
            obj.hModeDelete.Value=1;
        end
end
end

function [m, t]=convertStructArrayToMarkerAndTypeArrays(s)
    f=fieldnames(s);
    t(numel(f))=goggleMarkerType;
    m=[];
    for ii=1:numel(f)
        t(ii).name=f{ii};
        t(ii).color=s.(f{ii}).color;
        if isfield(s.(f{ii}), 'markers')
            sm=s.(f{ii}).markers;
            m=[m goggleMarker(t(ii), [sm.x], [sm.y], [sm.z])]; %#ok<AGROW>
        end
    end
end

function [markerX, markerY]=correctXY(obj, markerX, markerY, markerZ)
    zvm=obj.goggleViewer.mainDisplay.zoomedViewManager;
    if isempty(zvm.xyPositionAdjustProfile)
        return
    else
        offsets=zvm.xyPositionAdjustProfile(markerZ, :);
        markerX=markerX+offsets(: , 2)';
        markerY=markerY+offsets(: , 1)';
    end
        
end

%% Set up context menus to change markers
function setNameChangeContextMenu(h, obj)
mnuChangeMarkerName=uicontextmenu;
uimenu(mnuChangeMarkerName, 'Label', 'Change name...', 'Callback', {@changeMarkerTypeName, h, obj})
h.UIContextMenu=mnuChangeMarkerName;
end

function setColorChangeContextMenu(h, obj)
mnuChangeMarkerColor=uicontextmenu;
uimenu(mnuChangeMarkerColor, 'Label', 'Change color...','Callback', {@changeMarkerTypeColor, h, obj})
h.UIContextMenu=mnuChangeMarkerColor;
end

%% Marker change callbacks
function changeMarkerTypeName(~, ~, obj, parentObj)
oldName=obj.String;
proposedNewName=inputdlg('Change marker name to:', 'Cell Counter: Change Marker Name', 1, {oldName});

if isempty(proposedNewName)
    return
else
    proposedNewName=matlab.lang.makeValidName(proposedNewName{1});
end
if ismember(proposedNewName, {parentObj.markerTypes.name})
    msgbox(sprintf('Name %s is alread taken!', proposedNewName), 'Cell Counter')
    return
end
%% Change type
oldType=parentObj.markerTypes(obj.UserData);
newType=oldType;newType.name=proposedNewName;
parentObj.markerTypes(obj.UserData)=newType;

%% Change matching markers
if ~isempty(parentObj.markers)
    markersWithOldTypeIdx=find([parentObj.markers.type]==oldType);
    for ii=1:numel(markersWithOldTypeIdx)
        parentObj.markers(markersWithOldTypeIdx(ii)).type=newType;
    end
end
%% Refresh panel
obj.String=proposedNewName;
%% Set change flag
            parentObj.changeFlag=1;
end

function changeMarkerTypeColor(~, ~, obj, parentObj)
oldType=parentObj.markerTypes(obj.UserData);
newCol=uisetcolor(oldType.color);
if numel(newCol)<3
    return
end
%% Change type
newType=oldType;newType.color=newCol;
parentObj.markerTypes(obj.UserData)=newType;
%% Change matching markers

if ~isempty(parentObj.markers)
    markersWithOldTypeIdx=find([parentObj.markers.type]==oldType);
    for ii=1:numel(markersWithOldTypeIdx)
        parentObj.markers(markersWithOldTypeIdx(ii)).type=newType;
    end
end

%% Change panel indicator
set(findobj(parentObj.hColorIndicatorPanel, 'UserData', obj.UserData), 'BackgroundColor', newType.color);

%% Redraw markers
parentObj.drawMarkers;
%% Set change flag
            parentObj.changeFlag=1;
end

%% Settings change
function setUpSettingBox(displayName, settingName, yPosition, parentPanel, parentObject)
    fn=gbSetting('font.name');
    fs=gbSetting('font.size');
    
    hEdit=uicontrol(...
        'Style', 'edit', ...
        'Parent', parentPanel, ...
        'Units', 'normalized', ...
        'Position', [0.66 yPosition+0.05 0.32 0.09], ...
        'FontName', fn, ...
        'FontSize', fs, ...
        'BackgroundColor', gbSetting('viewer.mainBkgdColor'), ...
        'ForegroundColor', gbSetting('viewer.textMainColor'), ...
        'UserData', settingName);
    
    hEdit.String=num2str(gbSetting(settingName));
    hEdit.Callback={@checkAndUpdateNewNumericSetting, parentObject};
    
    uicontrol(...
        'Style', 'text', ...
        'Parent', parentPanel, ...
        'Units', 'normalized', ...
        'Position', [0.02 yPosition+0.035 0.61 0.07], ...
        'HorizontalAlignment', 'right', ...
        'FontName', fn, ...
        'FontSize', fs-1, ...
        'BackgroundColor', gbSetting('viewer.mainBkgdColor'), ...
        'ForegroundColor', gbSetting('viewer.textMainColor'), ...
        'String', displayName);

end

function checkAndUpdateNewNumericSetting(obj,ev, parentObject)
    numEquiv=(str2num(ev.Source.String)); %#ok<ST2NM>
    if ~isempty(numEquiv)
        gbSetting(obj.UserData, numEquiv)
    else
        obj.String=num2str(gbSetting(obj.UserData));
    end
    parentObject.drawMarkers();
end






