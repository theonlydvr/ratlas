classdef Path < handle & matlab.mixin.Copyable
    
    properties
        id
        parts
        fill_color
        stroke_color
        linestyle
    end
    
    methods
        function obj = Path(thisItem, parent)
            obj.id = thisItem.Attributes(strcmp({thisItem.Attributes.Name},'id')).Value;
            polyStr=thisItem.Attributes(strcmp({thisItem.Attributes.Name},'d')).Value;
            
            % Get any parent transformations
            transforms = {};
            if any(strcmp({parent.Attributes.Name},'transform'))
                transform=parent.Attributes(strcmp({parent.Attributes.Name},'transform')).Value;
                C = strsplit(transform,{';'});
                transforms = cell(length(C), 2);
                for i =1:length(C)
                    transforms{i,1} = extractBefore(C{i},'(');
                    transforms{i,2} = extractBetween(C{i},'(',')');
                end
            end
        
            % Get style attributes
            style=thisItem.Attributes(strcmp({thisItem.Attributes.Name},'style')).Value;
            mapObj = containers.Map;
            C = strsplit(style,{';'});
            for i =1:length(C)
                D = strsplit(C{i},{':'});           
                mapObj(D{1}) = D{2};
            end
            col=mapObj('fill');
            if mapObj.isKey('opacity')
                opacity=str2double(mapObj('opacity'));
            else
                opacity=1;
            end
            if ~strcmp(col,'none')
                r=hex2dec(col(2:3))/255;
                g=hex2dec(col(4:5))/255;
                b=hex2dec(col(6:7))/255;
                obj.fill_color=[r,g,b,opacity];
            else
                obj.fill_color='none';
            end
            
            col=mapObj('stroke');
            if ~strcmp(col,'none')
                r=hex2dec(col(2:3))/255;
                g=hex2dec(col(4:5))/255;
                b=hex2dec(col(6:7))/255;
                obj.stroke_color=[r,g,b,opacity];  
            else
                obj.stroke_color = 'none';
            end
        
            if mapObj.isKey('stroke-dasharray')
                linestyle=mapObj('stroke-dasharray');
                if ~strcmp(linestyle,'none')
                    obj.linestyle = '--';
                else
                    obj.linestyle ='-';
                end
            else
                obj.linestyle ='-';
            end
        
            commands = [find(isletter(polyStr)&polyStr~='e'),length(polyStr)+1];
            curPath = [];
            curPoint = [];
            pathStart = [];
            obj.parts = {};
            for i=1:length(commands)-1
                if polyStr(commands(i)) == 'm' || polyStr(commands(i)) == 'M'
                    if ~isempty(curPath)
                        obj.parts = [obj.parts, {curPath}];
                        curPath = [];
                    end
                    points = strip(extractBetween(polyStr,commands(i)+2,commands(i+1)-1));
                    points = str2double(split(split(points," "),","));
                    if size(points,1) > 1 && size(points,2) > 1
                        if isempty(curPoint)
                            curPoint = points(1,:);
                        else
                            curPoint = curPoint + points(1,:);
                        end
                        pathStart = curPoint;
                        if polyStr(commands(i)) == 'm'
                            points(2:end,:) = cumsum(points(2:end,:),1) + repmat(curPoint,size(points,1)-1,1);
                        end
                        curPoint = points(end,:);
                        curPath = [curPath;points];
                    else
                        if polyStr(commands(i)) == 'm' && ~isempty(curPoint)
                            curPoint = curPoint + points';
                        else
                            curPoint = points';
                        end
                        pathStart = curPoint;
                    end
                elseif polyStr(commands(i)) == 'c' || polyStr(commands(i)) == 'C'
                    points = strip(extractBetween(polyStr,commands(i)+2,commands(i+1)-1));
                    points = str2double(split(split(points," "),","));
                    N = length(points);
                    P = zeros(501*N/3,2); 
                    sigma = factorial(3)./(factorial(0:3).*factorial(3-(0:3)));
                    inds = 1:3:N;
                    for j=1:length(inds)
                        l=[];
                        UB=[];
                        for u=0:0.002:1
                            for d=1:3+1
                                UB(d)=sigma(d)*((1-u)^(3+1-d))*(u^(d-1));
                            end
                            l=cat(1,l,UB);                                      %catenation 
                        end
                        if polyStr(commands(i)) == 'c'
                            pts = [curPoint; points(inds(j):inds(j)+2,:)+repmat(curPoint,3,1)];
                        else
                            pts = [curPoint; points(inds(j):inds(j)+2,:)];
                        end
                        P(501*(j-1)+1:501*j,:)=l*pts;
                        curPoint = pts(end,:);
                    end
                    curPath = [curPath;P];
                elseif polyStr(commands(i)) == 'h' || polyStr(commands(i)) == 'H'
                    points = str2double(split(strip(extractBetween(polyStr,commands(i)+2,commands(i+1)-1)," ")));
                    if polyStr(commands(i)) == 'h'
                        points = curPoint(1) + cumsum(points);
                    end
                    points = [[curPoint(1);points],curPoint(2)*ones(length(points)+1,1)];
                    curPath = [curPath;points];
                    curPoint = points(end,:);
                elseif polyStr(commands(i)) == 'v' || polyStr(commands(i)) == 'V'
                    points = str2double(split(strip(extractBetween(polyStr,commands(i)+2,commands(i+1)-1)," ")));
                    if polyStr(commands(i)) == 'v'
                        points = curPoint(2) + cumsum(points);
                    end
                    points = [curPoint(1)*ones(length(points)+1,1),[curPoint(2);points]];
                    curPath = [curPath;points];
                    curPoint = points(end,:);
                elseif polyStr(commands(i)) == 'l' || polyStr(commands(i)) == 'L'
                    points = strip(extractBetween(polyStr,commands(i)+2,commands(i+1)-1));
                    points = str2double(split(split(points," "),","));
                    if size(points,2) < 2
                        points = points';
                    end
                    if polyStr(commands(i)) == 'l'
                        points = repmat(curPoint,size(points,1),1) + cumsum(points,1);
                    end
                    curPath = [curPath;points];
                    curPoint = points(end,:);
                elseif polyStr(commands(i)) == 'z' || polyStr(commands(i)) == 'Z'
                    curPath = [curPath;pathStart];
                    curPoint = pathStart;
                    obj.parts = [obj.parts, {curPath}];
                    curPath = [];
                else
                    disp(polyStr(commands(i)))
                end
            end
            if ~isempty(curPath)
                obj.parts = [obj.parts, {curPath}];
            end
            obj.transform(transforms);
        end

        function cut(obj, L, s)
            for i=1:length(obj.parts)
                obj.parts{i} = cutPolygon(obj.parts{i}, L, s);
            end
        end

        function invert_color(obj)
            if ~strcmp(obj.fill_color, 'none')
                obj.fill_color(1:3) = 1 - obj.fill_color(1:3);
            end
            if ~strcmp(obj.stroke_color, 'none')
                obj.stroke_color(1:3) = 1 - obj.stroke_color(1:3);
            end
        end

        function gobjs = plot(obj, use3D, group, plot_fill)
            if nargin < 4
                plot_fill = true;
            end
            if nargin < 3
                group = gca;
            end
            if nargin < 2
                use3D = false;
            end
            gobjs = [];
            if ~strcmp(obj.fill_color,'none') && plot_fill
                points = cell2mat(obj.parts');
                if use3D
                    gobjs = [gobjs, patch('xdata',points(:,1),'ydata',points(:,2), 'zdata', zeros(size(points,1),1), 'FaceColor',obj.fill_color(1:3),'FaceAlpha',obj.fill_color(4),'EdgeColor','none', 'Parent', group)];
                else
                    gobjs = [gobjs, patch('xdata',points(:,1),'ydata',points(:,2),'FaceColor',obj.fill_color(1:3),'FaceAlpha',obj.fill_color(4),'EdgeColor','none', 'Parent', group)];
                end
            end
            if ~strcmp(obj.stroke_color,'none')
                for i=1:length(obj.parts)
                    if use3D
                        gobjs = [gobjs, line(obj.parts{i}(:,1),obj.parts{i}(:,2),zeros(size(obj.parts{i},1),1),'Color',obj.stroke_color,'LineStyle',obj.linestyle, 'Parent', group)];
                    else
                        gobjs = [gobjs, line(obj.parts{i}(:,1),obj.parts{i}(:,2),'Color',obj.stroke_color,'LineStyle',obj.linestyle, 'Parent', group)];
                    end
                end
            end
        end

        function obj = transform(obj, transforms)
            obj.parts = cellfun(@(x) obj.transformPoints(x,transforms), obj.parts,'UniformOutput',false);
        end

        function BW = to_mask(obj, m, n)
            BW = false(m, n);
            if ~strcmp(obj.fill_color, 'none')
                for i=1:length(obj.parts)
                    BW = BW | poly2mask(obj.parts{i}(:,1), obj.parts{i}(:,2), m, n);
                end
            end
        end

        function BB = bounding_box(obj)
            BB = nan(1,4);
            for i=1:length(obj.parts)
                BB(1:2) = min([BB(1:2);obj.parts{i}],[],'omitnan');
                BB(3:4) = max([BB(3:4);obj.parts{i}],[],'omitnan');
            end
        end
    end

    methods(Static)
        function pointsNew = transformPoints(points, transforms)
            pointsNew = points;
            for i=1:size(transforms,1)
                if strcmp(transforms{i,1},'scale')
                    sf = str2double(split(transforms(i,2),','))';
                    pointsNew = pointsNew .* repmat(sf,size(pointsNew,1),1);
                end
                if strcmp(transforms{i,1},'translate')
                    shift = str2double(split(transforms(i,2),','))';
                    pointsNew = pointsNew + repmat(shift,size(pointsNew,1),1);
                end
                if strcmp(transforms{i,1},'rotate')
                    theta = str2double(transforms(i,2));
                    R = [cosd(theta) -sind(theta); sind(theta) cosd(theta)];
                    pointsNew = pointsNew * R;
                end
            end
        end
    end
end

