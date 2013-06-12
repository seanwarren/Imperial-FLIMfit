
function[delays,im_data,t_int,tcspc,metadata] = load_flim_file(file,channel,block)

global buf buf_name

%Opens a set if .tiffs, .pngs or a .sdt file into 
%into a 3d image of dimensions [num_time_points,height,width]

    % Copyright (C) 2013 Imperial College London.
    % All rights reserved.
    %
    % This program is free software; you can redistribute it and/or modify
    % it under the terms of the GNU General Public License as published by
    % the Free Software Foundation; either version 2 of the License, or
    % (at your option) any later version.
    %
    % This program is distributed in the hope that it will be useful,
    % but WITHOUT ANY WARRANTY; without even the implied warranty of
    % MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    % GNU General Public License for more details.
    %
    % You should have received a copy of the GNU General Public License along
    % with this program; if not, write to the Free Software Foundation, Inc.,
    % 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
    %
    % This software tool was developed with support from the UK 
    % Engineering and Physical Sciences Council 
    % through  a studentship from the Institute of Chemical Biology 
    % and The Wellcome Trust through a grant entitled 
    % "The Open Microscopy Environment: Image Informatics for Biological Sciences" (Ref: 095931).

    % Author : Sean Warren


    tcspc = 0;              % default is 'not tcspc'

    t_int = [];
    metadata = struct();
    
    if (nargin < 2)
        channel = -1;
    end
    if (nargin < 3)
        block = -1;
    end

    [path,fname,ext] = fileparts(file);

    if strcmp(ext,'.tiff')
        ext = '.tif';
    end
    
    switch ext

        % .tif files %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        case '.tif'
            
            if length(fname) > 5 && strcmp(fname(end-3:end),'.ome')
                
                info = imfinfo(file);
                
                n_im = length(info);
                sz = [n_im info(1).Height info(1).Width];
                im_data = zeros(sz);
                
                % Now gets bin spacing from file header rather than assuming 12.5ns
                delays = (0:(n_im-1))/n_im*11.94e3;
                
                %{
                % get binSpacing from file header
                tT = Tiff(file);
                s = tT.getTag('ImageDescription');
                pos = strfind(s,'PhysicalSizeZ');
                binSpacing = 1000 .* str2double(s(pos+15:pos+20));          %binSpacing in ps

                delays = (0:(n_im - 1)) .* binSpacing;
                %}

                
                for i=1:n_im
                    im_data(i,:,:) = imread(file,'Index',i,'Info',info);
                    
                end
                
            else
                dirStruct = [dir([path filesep '*.tif']) dir([path filesep '*.tiff'])];
                siz = size(dirStruct);
                noOfFiles = siz(1);

                if noOfFiles == 0
                    im_data = [];
                    delays = [];
                    return
                end

                first = [path filesep dirStruct(1).name];
                im = imread(first,'tif');

                im_data = zeros([noOfFiles size(im)],'uint16');
                delays = zeros([1,noOfFiles]);
                
                im_data(1,:,:) = im;
                
                for f = 2:noOfFiles
                    filename = [path filesep dirStruct(f).name];
                    [~,name] = fileparts(filename);
                    tokens = regexp(name,'INT\_(\d+)','tokens');
                    if ~isempty(tokens)
                        t_int(f) = str2double(tokens{1});
                    end
                    
                    tokens = regexp(name,'(?:^|\s)T\_(\d+)','tokens');
                    if ~isempty(tokens)
                        delays(f) = str2double(tokens{1});
                    else
                        name = name(end-4:end);      %last 6 chars contains delay 
                        delays(f) = str2double(name);                       
                    end

                    try
                        im_data(f,:,:) = imread(filename,'tif');
                    catch error
                        throw(error);
                    end
                end

                [delays, sort_idx] = sort(delays);
                im_data = im_data(sort_idx,:,:);
                
                if min(im_data(:)) > 32500
                    im_data = im_data - 32768;    % clear the sign bit which is set by labview
                end
            end
                
         % .sdt files %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%   
         case '.sdt'


             [im_data, delays]=loadBHfileusingmeasDescBlock(file,channel,block);
             tcspc = 1;


         % .asc files %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%     
         case '.asc'
             tcspc = 1;

             dataUnShaped = dlmread(file);
             siz = size(dataUnShaped);
             if length(siz) == 2      % if  data is not 3d
                 if siz(1) == 2     % looks like this includes delays
                     step = dataUnShaped(1,3)/dataUnShaped(1,2);
                     if step > 1.99 && step < 2.01
                         dataUnShaped = squeeze(dataUnShaped(2,:));   % discard delays
                     else
                         dataUnShaped = squeeze(dataUnShaped(1,:));
                     end
                 end
                 if siz(2) == 2     % looks like this includes delays
                     step = dataUnShaped(3,1)/dataUnShaped(2,1);
                     if step > 1.99 && step < 2.01
                         dataUnShaped = squeeze(dataUnShaped(:,2));   % discard delays
                     else
                         dataUnShaped =  squeeze(dataUnShaped(:,1));
                     end
                 end
             end


             res = sqrt(size(dataUnShaped,1)/64);
             if res >= 1 
                im_data = reshape(dataUnShaped, 64, res, res);
                delays = (0:63)*12500.0/64;
             else
                 im_data = dataUnShaped;
                delays = (0:length(im_data)-1)*12500.0/64;
             end



          % .txt files %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
          case '.txt'
             tcspc = 1;

             % check if we're reading a TRFA file
             fid = fopen(file);
             first_line = fgetl(fid);
             fclose(fid);

             if strcmp(first_line,'TRFA_IC_1.0')
                throw(MException('FLIM:CannotOpenTRFA','Cannot open TRFA formatted files'));
             else

                 fid = fopen(file);
             
                 header_lines = 0;
                 textl = fgetl(fid);
                 while ~isempty(textl)
                     first = sscanf(textl,'%f\t');
                     if isempty(first)
                         header_lines = header_lines + 1;
                         textl = fgetl(fid);
                     else 
                         textl = [];
                     end                 
                 end
                
                 fclose(fid);

             
                 % buf and buf_name are global variables, but of a hack to 
                 % speed up loading multiple channels of a text file
                 
                 if ~isempty(buf_name) && strcmp(buf_name,file)
                     ir = buf;
                 else
                     ir = dlmread(file,'\t',header_lines,0);
                     buf_name = file;
                     buf = ir;
                 end
                 
                 
                 if max(channel) > (size(ir,2)-1)
                     throw(MException('FLIM:ChannelNotFound','A specified channel was not found in the file'));
                 end
                 
                 % first column is delays so channel i is column 2 etc
                 for c=1:length(channel);
                     im_data(:,c,1,1) = ir(:,channel(c) + 1); %#ok
                 end

%                 metadata.()
                 
                 delays(1,:) = ir(:,1);

                 im_data = im_data(~isnan(delays),:,:,:);
                 delays = delays(~isnan(delays));

                 if max(delays) < 1000
                    delays = delays * 1000;
                 end
             end

        case '.irf'        % Yet another F%^^ing format (for Labview this time)
            tcspc = 1;    
            ir = load(file);

            im_data(:,1,1) = ir(:,2);    
            delays(1,:) = ir(:,1);  %.*1000;
    end
    
    s = size(im_data);
    if length(s) == 3
        im_data = reshape(im_data,[s(1) 1 s(2) s(3)]);
    end
    
    if length(t_int) ~= length(delays)
        t_int = ones(size(delays));
    end

end
    