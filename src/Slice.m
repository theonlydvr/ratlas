classdef Slice < handle & matlab.mixin.Copyable
    
    properties
        paths
        coord
        plane
        coord_atlas
    end
    
    methods
        function obj = Slice(coord, plane)
            obj.coord = coord;
            obj.plane = upper(plane);
            currentFile = mfilename('fullpath');
            [pathstr,~,~] = fileparts(currentFile);
            files = dir(fullfile(pathstr, "images"));
            files = files(3:end);
            valid = files(startsWith({files.name},upper(plane)));
            names = {valid.name};
            coords = str2double(strrep(strrep(extractBetween(names,upper(plane),'.svg'),'n','-'),'_','.'));
            [~,closest] = min(abs(coords-coord));
            obj.coord_atlas = coords(closest);
            obj.paths = loadSVG(fullfile(valid(closest).folder,valid(closest).name));
            [sfx, sfy, x0, y0] = obj.getValues(num2str(coords(closest)), plane);
            obj.translate(-x0, -y0);
            obj.scale(1/sfx, 1/sfy);
        end

        function cut(obj, l, s)
            for i=1:length(obj.paths)
                obj.paths(i).cut(l, s);
            end
        end

        function transform(obj, transforms)
            for i=1:length(obj.paths)
                obj.paths(i).transform(transforms);
            end
        end

        function translate(obj, x, y)
            transforms = {'translate', sprintf('%f,%f', x, y)};
            obj.transform(transforms);
        end

        function scale(obj, x, y)
            transforms = {'scale', sprintf('%f,%f', x, y)};
            obj.transform(transforms);
        end

        function rotate(obj, theta)
            transforms = {'rotate', num2str(theta)};
            obj.transform(transforms);
        end

        function invert_color(obj)
            for i=1:length(obj.paths)
                obj.paths(i).invert_color();
            end
        end

        function group = plot_ref_line(obj, group)
            if nargin < 2
                group = gca;
            end

            if strcmpi(obj.plane, 'c')
                line('xdata', [obj.coord,obj.coord], 'ydata', [-12,0], 'Color', 'k')
            elseif strcmpi(obj.plane, 'h')
                line('xdata', [-15, 8], 'ydata', [obj.coord,obj.coord], 'Color', 'k')
            end
        end

        function group = plot(obj, use3D, plot_fill)
            if nargin < 3
                plot_fill = true;
            end
            if nargin < 2
                use3D = false;
            end
            group = hggroup;
            for i=1:length(obj.paths)
                gobjs = obj.paths(i).plot(use3D, group, plot_fill);
                if use3D
                    for j=1:length(gobjs)
                        gobj = gobjs(j);
                        if strcmpi(obj.plane,'c')
                            gobj.ZData = obj.coord * ones(size(gobj.ZData));
                        elseif strcmpi(obj.plane,'h')
                            x = gobj.XData;
                            y = gobj.YData;
                            z = obj.coord * ones(size(gobj.ZData));
                            gobj.XData = y;
                            gobj.YData = z;
                            gobj.ZData = -x;
                        elseif strcmpi(obj.plane,'s')
                            x = gobj.XData;
                            y = gobj.YData;
                            z = obj.coord * ones(size(gobj.ZData));
                            gobj.XData = z;
                            gobj.YData = y;
                            gobj.ZData = -x;
                        end
                    end
                end
            end
        end

        function BB = bounding_box(obj)
            BB = nan(1,4);
            for i=1:length(obj.paths)
                bb = obj.paths(i).bounding_box();
                BB(1:2) = min([BB(1:2);bb(1:2)],[],'omitnan');
                BB(3:4) = max([BB(3:4);bb(3:4)],[],'omitnan');
            end
        end

        function BW = to_mask(obj, m, n)
            BW = false(m, n);
            for i=1:length(obj.paths)
                BW = BW | obj.paths(i).to_mask(m, n);
            end
        end

        function [snew, p] = overlay(obj, I)
            BB = obj.bounding_box();
            sx0 = size(I,2) / (BB(3)-BB(1));
            sy0 = size(I,1) / (BB(4)-BB(2));
            snew = copy(obj);
            transforms = {'translate', sprintf('%f,%f', -BB(1), -BB(2));...
                          'scale', sprintf('%f,%f', sx0, sy0)};
            snew.transform(transforms);
            BW2 = flip(snew.to_mask(size(I,1), size(I,2)));
            points = detectSURFFeatures(BW2);
            points2 = detectSURFFeatures(I);
            [features1, validPoints1] = extractFeatures(BW2, points);
            [features2, validPoints2] = extractFeatures(I, points2);
            indexPairs = matchFeatures(features1, features2);
            matchedPoints1 = validPoints1(indexPairs(:, 1), :);
            matchedPoints2 = validPoints2(indexPairs(:, 2), :);
            [tform, inlierIdx] = estgeotform2d(matchedPoints1,matchedPoints2,'similarity');
            out = imwarp(BW2, tform);
%             p = patternsearch(@(x) obj.mask_compare(I,copy(obj),x), [tx0,0,sx0,sy0,0],[],[],[],[],[-Inf,-Inf,0,0],[Inf, Inf, sx0, sy0, 360]);
%             tx = p(1); ty = p(2); sx = p(3); sy = -p(4); r = p(5);
%             transforms = {'scale', sprintf('%f,%f', sx, sy);
%                           'rotate', num2str(r);
%                           'translate', sprintf('%f,%f', tx, ty)};
%             snew = copy(obj);
%             snew.transform(transforms);
        end
    end

    methods(Static)
        function group = plot_reference()
            group = hggroup;
            currentFile = mfilename('fullpath');
            [pathstr,~,~] = fileparts(currentFile);
            ref_paths = loadSVG(fullfile(pathstr,'images', 'P.svg'));
            transforms = {'translate', sprintf('%f,%f', -318.27, -903.278);...
                          'scale', sprintf('%f,%f', -1/5.224, 1/5.224)};
            for i=1:length(ref_paths)
                ref_paths(i).transform(transforms);
                ref_paths(i).plot(false, group)
            end
        end

        function P = mask_compare(BW, slice, x)
            tx = x(1); ty = x(2); sx = x(3); sy = -x(4); r = x(5);
            transforms = {'scale', sprintf('%f,%f', sx, sy);
                          'rotate', num2str(r);
                          'translate', sprintf('%f,%f', tx, ty)};
            slice.transform(transforms);
            BW2 = slice.to_mask(size(BW,1), size(BW,2));
            P = -nnz(BW & BW2) / nnz(BW | BW2);
        end

        function [sfx, sfy, x0, y0] = getValues(coord, plane)
            if strcmpi(plane,'c')
                switch(coord)
                    case {'7.56', '7.08', '6.6', '6.12', '5.64', '-8.4', '-8.52', '-8.64', '-8.76', '-8.88', '-9', ...
                            '-9.12', '-9.24', '-9.36', '-9.48', '-9.6', '-9.72', '-9.84', '-9.96', '-10.08', '-10.2', ...
                            '-10.32', '-10.44', '-10.56', '-10.68', '-10.8', '-10.92', '-11.04', '-11.16', '-11.28', ...
                            '-11.4', '-11.52', '-11.64', '-11.76', '-11.88', '-12', '-12.12', '-12.24', '-12.36', '-12.48', ...
                            '-12.60', '-12.72', '-12.84', '-12.96', '-13.08', '-13.2', '-13.32', '-13.44', '-13.56', '-13.68'}
                        sfx = 56.7560;
                        sfy = 56.7560;
                        x0 = 539.875;
                        y0 = 977.467;
                    case {'5.16', '4.68', '4.2', '3.72', '3.24', '3', '-0.24', '-0.36', '-0.48', '-0.6', '-0.72', ...
                            '-0.84', '-0.96', '-1.08', '-1.2', '-1.32', '-1.44', '-1.56', '-1.72', '-1.8', '-1.92', ...
                            '-2.04', '-2.16', '-2.28', '-2.4', '-2.52', '-2.64', '-2.76', '-2.92', '-3', '-3.12', ...
                            '-3.24', '-3.36', '-3.48', '-3.6', '-3.72', '-3.84', '-3.96', '-4.08', '-4.2', '-4.36', ...
                            '-4.44', '-4.56', '-4.68', '-4.8', '-4.92', '-5.04', '-5.16', '-5.28', '-5.4', '-5.52', ...
                            '-5.64', '-5.76', '-5.88', '-6', '-6.12', '-6.24', '-6.36', '-6.48', '-6.6', '-6.72', ...
                            '-6.84', '-6.96', '-7.08', '-7.2', '-7.32', '-7.44', '-7.56', '-7.68', '-7.8', '-7.92', ...
                            '-8.04', '-8.16', '-8.28', '-13.8', '-13.92', '-14.04', '-14.16', '-14.28', '-14.4', ...
                            '-14.52', '-14.64', '-14.76', '-15', '-15.24', '-15.48', '-15.72', '-15.96'}
                        sfx = 56.756;
                        sfy = 56.756;
                        x0 = 539.875;
                        y0 = 920.713;
                    case {'2.76', '2.52', '2.28', '2.16', '2.04', '1.92', '1.8', '1.68', '1.56', '1.44', '1.32', ...
                            '1.2', '1.08', '0.96', '0.84', '0.72', '0.6', '0.48', '0.36', '0.24', '0.12', '0', ...
                            '-0.12'}
                        sfy = 56.756;
                        sfx = 56.756;
                        x0 = 539.875;
                        y0 = 863.956;
                end
            elseif strcmpi(plane,'h')
                    sfy = 41.303;
                    sfx = 41.274;
                    x0 = 333.469;
                    y0 = 590.301;
            elseif strcmpi(plane,'s')
                    sfy = 41.261;
                    sfx = 41.261;
                    x0 = 333.469;
                    y0 = 879.788;
            end
        end
    end

    methods(Access = protected)
        function cp = copyElement(obj)
            cp = copyElement@matlab.mixin.Copyable(obj);
            cp.paths = Path.empty(length(obj.paths),0);
            for i=1:length(obj.paths)
                cp.paths(i) = copy(obj.paths(i));
            end
        end
    end
end
