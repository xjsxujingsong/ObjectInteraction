function mcmc_prediction_parfor(cls)

matlabpool open 3

switch cls
    case 'car';
        path_image = '../Images/car';
        N = 200;
        cls_cad = {'car'};
    case 'bed';
        path_image = '../Images/room';
        N = 300;
        cls_cad = {'bed'};
    case 'chair';
        path_image = '../Images/room';
        N = 300;
        cls_cad = {'chair'};        
    case 'sofa';
        path_image = '../Images/room';
        N = 300;
        cls_cad = {'sofa'};        
    case 'room'
        path_image = '../Images/room';
        N = 300;
        cls_cad = {'bed', 'chair', 'sofa', 'table'};
end

% load cad model
cad_num = numel(cls_cad);
cads = cell(cad_num, 1);
for i = 1:cad_num
    object = load(sprintf('data_final/%s.mat', cls_cad{i}));
    cads{i} = object.(cls_cad{i});
end

% padding of original image
[padx, pady] = get_padding(cads);

parfor i = 1:N
    task = getCurrentTask();
    % read image
    filename = sprintf('%s/%04d.jpg', path_image, i);
    I = imread(filename);
    % run detectors
    labels = cell(cad_num, 1);
    trees = cell(cad_num, 1);    
    for j = 1:cad_num
        num = numel(cads{j});
        labels{j} = cell(num, 1);
        trees{j} = cell(num, 1);
        % for each aspectlets
        for k = 1:num
            filename = sprintf('data_final/%s_final_cad%03d.mod', cls_cad{j}, k-1);
            cad_one = cell(1,1);
            cad_one{1} = cads{j}(k);
            model = read_model(filename, cad_one);
            model.padx = padx;
            model.pady = pady;
            [y, tree] = svm_empty_classify_matlab(double(I), cad_one, model, task.ID);
            labels{j}{k} = y;
            trees{j}{k} = tree{1};
            fprintf('Image %d, cad %d, model %d: %d object detected\n', i, j, k, numel(y));
        end
    end
    filename = sprintf('results/%s_%03d.mat', cls, i);
    parsave(filename, labels, trees);
end

matlabpool close

function parsave(filename, labels, trees)

save(filename, 'labels', 'trees', '-v7.3');