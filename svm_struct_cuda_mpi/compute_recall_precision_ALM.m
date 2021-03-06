% compute recall and precision
function [recall, precision, ap] = compute_recall_precision_ALM(cls, isfigure)

switch cls
    case 'car'
        cls_data = 'car';
        cls_cad = 'car';
        index_test = 1:200;
        object = load(sprintf('../CAD/%s_full.mat', cls_cad));
    case 'car_ALM'
        cls_data = 'car';
        cls_cad = 'car';
        index_test = 1:200;
        object = load(sprintf('../../Aspect_Layout_Model/CAD/%s.mat', cls_cad));        
    case 'car_3D'
        cls_data = 'car_3D';
        cls_cad = 'car';
        index_test = 241:480;
        object = load(sprintf('../CAD/%s_full.mat', cls_cad));
    case 'bed_ALM'
        cls_data = 'room';
        cls_cad = 'bed';
        index_test = 1:300;
        object = load(sprintf('../../Aspect_Layout_Model/CAD/%s.mat', cls_cad));         
    case 'chair_ALM'
        cls_data = 'room';
        cls_cad = 'chair';
        index_test = 1:300;
        object = load(sprintf('../../Aspect_Layout_Model/CAD/%s.mat', cls_cad));
    case 'sofa_ALM'
        cls_data = 'room';
        cls_cad = 'sofa';
        index_test = 1:300;
        object = load(sprintf('../../Aspect_Layout_Model/CAD/%s.mat', cls_cad));
    case 'table_ALM'
        cls_data = 'room';
        cls_cad = 'table';
        index_test = 1:300;
        object = load(sprintf('../../Aspect_Layout_Model/CAD/%s.mat', cls_cad));        
    case 'bed_full'
        cls_data = 'room';
        cls_cad = 'bed';
%         object = load('data/bed.mat');
%         index_test = object.index_test;
        index_test = 1:300;
        object = load(sprintf('../CAD/%s_full.mat', cls_cad));        
    case 'chair_full'
        cls_data = 'room';
        cls_cad = 'chair';
%         object = load('data/chair.mat');
%         index_test = object.index_test;
        index_test = 1:300;
        object = load(sprintf('../CAD/%s_full.mat', cls_cad));
    case 'sofa_full'
        cls_data = 'sofa';
        cls_cad = 'sofa';
        object = load('data/sofa.mat');
        index_test = object.index_test;
        object = load(sprintf('../CAD/%s_full.mat', cls_cad));
    case 'table_full'
        cls_data = 'room';
        cls_cad = 'table';
%         object = load('data/table.mat');
%         index_test = object.index_test;
        index_test = 1:300;
        object = load(sprintf('../CAD/%s_full.mat', cls_cad));        
end

% load cad model
cad = object.(cls_cad);

M = numel(index_test);
path_anno = sprintf('../Annotations/%s', cls_data);
path_image = sprintf('../Images/%s', cls_data);

% open prediction file
pre_file = sprintf('data_new/%s.pre', cls);
fpr = fopen(pre_file, 'r');

energy = [];
correct = [];
overlap = [];
count = zeros(M,1);
num = zeros(M,1);
num_pr = 0;
for i = 1:M
    % read ground truth bounding box
    index = index_test(i);
    file_ann = sprintf('%s/%04d.mat', path_anno, index);
    image = load(file_ann);
    object = image.object;
    bbox = object.bbox;
    if isfield(object, 'class') == 1
        tmp = strcmp(cls_cad, object.class);
        bbox = bbox(tmp,:);
    end
    bbox = [bbox(:,1) bbox(:,2) bbox(:,1)+bbox(:,3) bbox(:,2)+bbox(:,4)];
    count(i) = size(bbox, 1);
    det = zeros(count(i), 1);
    
    % read image
    file_image = sprintf('%s/%04d.jpg', path_image, index);
    I = imread(file_image);      

    num(i) = fscanf(fpr, '%d', 1);
    % for each predicted bounding box
    for j = 1:num(i)
        example = read_sample(fpr, cad, 0);
        
        num_pr = num_pr + 1;
        energy(num_pr) = example.energy;
        % get predicted bounding box
        bbox_pr = example.bbox';
        
        bbox_pr(1) = max(1, bbox_pr(1));
        bbox_pr(2) = max(1, bbox_pr(2));
        bbox_pr(3) = min(bbox_pr(3), size(I,2));
        bbox_pr(4) = min(bbox_pr(4), size(I,1));        
        
        % compute box overlap
        if isempty(bbox) == 0
            o = box_overlap(bbox, bbox_pr);
            [maxo, index] = max(o);
            if maxo >= 0.5 && det(index) == 0
                overlap{num_pr} = index;
                correct(num_pr) = 1;
                det(index) = 1;
            else
                overlap{num_pr} = [];
                correct(num_pr) = 0;              
            end
        else
            overlap{num_pr} = [];
            correct(num_pr) = 0;
        end
    end
end
fclose(fpr);
overlap = overlap';

threshold = sort(energy);
n = numel(threshold);
recall = zeros(n,1);
precision = zeros(n,1);
for i = 1:n
    % compute precision
    num_positive = numel(find(energy >= threshold(i)));
    num_correct = sum(correct(energy >= threshold(i)));
    if num_positive ~= 0
        precision(i) = num_correct / num_positive;
    else
        precision(i) = 0;
    end
    
    % compute recall
    correct_recall = correct;
    correct_recall(energy < threshold(i)) = 0;
    num_correct = 0;
    start = 1;
    for j = 1:M
        for k = 1:count(j)
            for s = start:start+num(j)-1
                if correct_recall(s) == 1 && numel(find(overlap{s} == k)) ~= 0
                    num_correct = num_correct + 1;
                    break;
                end
            end
        end
        start = start + num(j);
    end
    recall(i) = num_correct / sum(count);
end

ap = VOCap(recall(end:-1:1), precision(end:-1:1));
leg{1} = sprintf('object (%.2f)', ap);
disp(ap);

if isfigure == 1
    % draw recall-precision curve
    figure;
    plot(recall, precision, 'r', 'LineWidth',3);
    h = legend(leg, 'Location', 'SouthWest');
    set(h,'FontSize',16);
    h = xlabel('Recall');
    set(h,'FontSize',16);
    h = ylabel('Precision');
    set(h,'FontSize',16);
    % tit = sprintf('Average Precision = %.1f', 100*ap);
    tit = sprintf('%s', cls);
    tit(1) = upper(tit(1));
    tit(tit == '_') = ' ';
    h = title(tit);
    set(h,'FontSize',16);
end