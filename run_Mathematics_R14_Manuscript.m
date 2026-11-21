function run_Mathematics_R14_Manuscript()
% RUN_MATHEMATICS_R14_MANUSCRIPT
% Excel-driven MATLAB workflow for the R14 manuscript:
% "Segmented Bezier Representation of Solar Wind Speed and a Local Activity Index"
%
% The program asks the user to select Excel workbooks for Set N, Set A,
% Set M and Sets 1-3, then asks for the four corresponding 3-hour Kp
% workbooks (M, 1, 2 and 3). The original observation order is preserved.
%
% MATLAB R2020a or later. No specialized toolbox is required.
% Outputs: manuscript tables in Excel, Figure 1-15 and A1-A12 as 600-dpi
% PNG and vector PDF, Figure_Index.csv, combined Kp CSV and RUN_SUMMARY.txt.

clc;
close all;
fprintf('\n============================================================\n');
fprintf(' MATHEMATICS R14 | SOLAR-WIND BEZIER AND LOCAL ACTIVITY INDEX\n');
fprintf('============================================================\n\n');

fillCodes = requestFillCodes();
D = loadManuscriptDatasetsInteractive(fillCodes);

fprintf('\nLoaded six manuscript datasets:\n');
for s=1:numel(D)
    fprintf('  Set %-2s: %4d observations, %4d missing values | %s\n', ...
        D(s).name,numel(D(s).y),sum(~isfinite(D(s).y)),D(s).sourceFile);
end

fprintf('\nSelect the four Excel workbooks containing the 3-hour Kp data.\n');
fprintf('The source files may contain hourly rows with each 3-hour Kp value repeated three times.\n');
Kp = loadKpWorkbooksInteractive();

outDir = uigetdir(pwd,'Select the output folder for the R14 analysis');
if isequal(outDir,0)
    error('Output-folder selection was cancelled.');
end
if ~exist(outDir,'dir'), mkdir(outDir); end
figDir = fullfile(outDir,'Figures');
if ~exist(figDir,'dir'), mkdir(figDir); end

kpPath = fullfile(outDir,'Kp_3h_Combined.csv');
kpTime=Kp.start_utc;
kpTime.Format="yyyy-MM-dd'T'HH:mm:ss'Z'";
KpOut = table(string(kpTime),Kp.kp,Kp.source_set, ...
    'VariableNames',{'start_utc','kp','source_set'});
writetable(KpOut,kpPath);

fprintf('\nAll Excel inputs have been read and validated.\n');
fprintf('Output folder: %s\n',outDir);

% Choose a full manuscript run or a fast preview. The full profile is
% the default and is required for final numerical tables. The preview skips
% GP/uncertainty resampling and uses fewer Kp bootstrap replicates.
profile=questdlg(['Choose the analysis profile:' newline newline ...
    'Full manuscript run: all analyses and manuscript replicate counts.' newline ...
    'Fast preview: figures and deterministic analyses; extended GP/bootstrap outputs are abbreviated.'], ...
    'R14 analysis profile','Full manuscript run','Fast preview','Full manuscript run');
if isempty(profile), profile='Full manuscript run'; end
runGP=strcmp(profile,'Full manuscript run');
runResampling=runGP;
if runGP
    kpBootstrapReplicates=5000;
else
    kpBootstrapReplicates=300;
end

% Manuscript baseline: eight overlapping intervals; LAI blocks: eight
% non-overlapping observations.
h = 8;
laiLength = 8;
degrees = 2:6;
classicalNames = {'Linear','Cubic spline','Hermite (PCHIP)','Lagrange'};
methodNames = [arrayfun(@(q)sprintf('Bezier degree %d',q),degrees,'UniformOutput',false),classicalNames];

R = repmat(resultTemplate(),1,numel(D));
for s=1:numel(D)
    fprintf('\n[%d/%d] Analysing Set %s...\n',s,numel(D),D(s).name);
    R(s).name = D(s).name;
    R(s).y = D(s).y(:);
    R(s).utc = D(s).utc(:);
    R(s).sourceFile = D(s).sourceFile;
    R(s).sourceSheet = D(s).sourceSheet;
    R(s).sourceColumn = D(s).sourceColumn;
    R(s).isConsecutive = D(s).isConsecutive;

    [R(s).P,R(s).starts,R(s).controls] = fitAll(R(s).y,h,degrees,true);
    [R(s).H,R(s).HY,R(s).HI,R(s).Hstarts,R(s).Hoffset] = ...
        heldAll(R(s).y,R(s).starts,h,degrees,true);
    [R(s).C1,R(s).C1Jumps] = continuousCubic(R(s).y,R(s).starts,h);
    R(s).fitMetrics = metricsByColumn(R(s).y,R(s).P);
    R(s).heldMetrics = metricsByColumn(R(s).HY,R(s).H);
    R(s).degreeRows = degreeSensitivityRows(R(s),h,degrees);
    R(s).continuityRows = continuityRows(R(s),h,2:4);
    R(s).fitTable = makeFitTable(R(s),methodNames);
    R(s).heldTable = makeHeldTable(R(s),methodNames);
    R(s).validFitMask = isfinite(R(s).P(:,1));
end

% LAI is calculated only for the four consecutive series (M and 2017 Sets 1-3).
for s=3:6
    R(s).LAI = calculateLAI(R(s).y,laiLength);
    R(s).LAI.utc = R(s).utc;
    R(s).LAI.name = R(s).name;
end

% Main-text tables.
T1 = makeDescriptiveTable(R(1:3));
T2 = makeBezierMainTable(R(1:3));
T3 = makeClassicalMainTable(R(1:3));
T4 = makeLAICountTable(R(3));
T5 = makeTopActivityTable(R(3));
T6 = makeWindowSensitivityTable(R(3),h);
T7 = makeCoverageTable(R(4:6));
[T8,T9] = makeAdditionalPeriodTables(R(4:6));
T10 = makeLAICountSummaryTable(R(4:6));
T11a = makeTopActivityTable(R(4));
T11b = makeTopActivityTable(R(5));
T11c = makeTopActivityTable(R(6));
T12 = makeComponentCorrelationTable(R(3:6));
T13 = makeLAISensitivitySummary(R(3:6));
T14 = makeDegreeSummaryTable(R);
T15 = makeResidualContinuitySummary(R([3 4 5 6]));
TOffset = makeCalibrationOffsetTable(R(3));

% Appendix tables A1-A7 and A10.
TA1 = makeLongWindowTable(R(4:6));
TA3 = makePCATable(R(3:6));
TA4 = makeLAIQuartileTable(R(3:6));
[TA5a,TA5b] = makeDegreeAppendixTables(R);
TA6 = makeContinuityAppendixTable(R);
TA7 = makeMATLABStorageTable(R(3));
TA10 = makeWilcoxonTable(R);

% Stochastic analyses.
TA2 = table();
TA9a = table();
TA9b = table();
T18 = table();
if runResampling
    fprintf('\nRunning moving-block bootstrap for Table A2...\n');
    TA2 = makeClassicalBootstrapTable(R(1:3),5000,4691220);
    fprintf('Running 1000-realization perturbation analyses for Tables 18/A9...\n');
    [TA9a,TA9b] = makePerturbationTables(R,1000,4691221);
    T18 = TA9a(strcmp(string(TA9a.Set),'M'),:);
end

% Common 24-interval fixed/adaptive/GP experiment.
T17 = table();
TA8a = table();
TA8b = table();
adaptiveM = struct();
gpDiagnostics = table();
if runGP
    fprintf('\nRunning adaptive-knot and Gaussian-process comparison.\n');
    fprintf('This is the most computationally intensive stage.\n');
    [T17,TA8a,TA8b,adaptiveM,gpDiagnostics] = makeAdaptiveGPComparison(R);
end

fprintf('\nMeasuring Set M fit/evaluation times (3 warm-ups + 21 repetitions)...\n');
T16 = makeRuntimeTable(R(3),h);

fprintf('\nCalculating the external LAI-Kp comparison...\n');
[T19,TA11] = makeKpTables(R(3:6),kpPath,kpBootstrapReplicates,4691222);

fprintf('\nCreating the 27 manuscript figures...\n');
figureIndex = createManuscriptFigures(R,figDir,adaptiveM,runGP);

% Complete computational output workbook.
xlsxFile = fullfile(outDir,'SolarWindSpeed_Bezier_LAI_Manuscript_Results.xlsx');
if isfile(xlsxFile), delete(xlsxFile); end
writeResultWorkbook(xlsxFile, ...
    {'Table_01',T1; 'Table_02',T2; 'Table_03',T3; 'Table_04',T4; 'Table_05',T5; ...
     'Table_06',T6; 'Table_07',T7; 'Table_08',T8; 'Table_09',T9; 'Table_10',T10; ...
     'Table_11a',T11a; 'Table_11b',T11b; 'Table_11c',T11c; 'Table_12',T12; ...
     'Table_13',T13; 'Table_14',T14; 'Table_15',T15; 'Table_16',T16; ...
     'Calibration_Offset_Check',TOffset; 'Table_17',T17; 'GP_Optimizer_Diagnostics',gpDiagnostics; ...
     'Table_18',T18; 'Table_19',T19; 'Table_A1',TA1; 'Table_A2',TA2; ...
     'Table_A3',TA3; 'Table_A4',TA4; 'Table_A5a',TA5a; 'Table_A5b',TA5b; ...
     'Table_A6',TA6; 'Table_A7',TA7; 'Table_A8a',TA8a; 'Table_A8b',TA8b; ...
     'Table_A9a',TA9a; 'Table_A9b',TA9b; 'Table_A10',TA10; 'Table_A11',TA11});

writetable(figureIndex,fullfile(outDir,'Figure_Index.csv'));
writeRunSummary(D,R,outDir,h,laiLength,runGP,runResampling,kpPath,methodNames,kpBootstrapReplicates);

fprintf('\n============================================================\n');
fprintf('Analysis completed.\n');
fprintf('Results workbook: %s\n',xlsxFile);
fprintf('Figures: %s\n',figDir);
fprintf('Figure count: %d\n',height(figureIndex));
fprintf('MATLAB version: %s\n',version);
fprintf('============================================================\n\n');
end

function fillCodes = requestFillCodes()
a = inputdlg({'Enter any additional numeric fill codes separated by commas (9999 is always treated as missing):'}, ...
    'Missing/fill-value handling',1,{''});
if isempty(a)
    error('Fill-code entry was cancelled.');
end
z = str2double(strsplit(strrep(a{1},';',','),','));
z = z(isfinite(z));
fillCodes = unique([9999 z(:)']);
end

function D = loadManuscriptDatasetsInteractive(fillCodes)
names = {'N','A','M','1','2','3'};
expected = [2706 2706 2706 2880 2952 2928];
D = repmat(struct('name','','y',[],'utc',[],'sourceFile','','sourceSheet','', ...
    'sourceColumn','','isConsecutive',false),1,6);

for s=1:6
    nm=names{s};
    [T,fullPath,sheetName] = selectExcelTable( ...
        sprintf('Select the Excel workbook for Set %s',nm));
    timeIdx = findTimeColumn(T);
    yIdx = chooseMeasurementColumn(T,nm,timeIdx,'solar-wind speed');
    rawY = T{:,yIdx};
    y = numericColumn(rawY);
    y = y(:);
    if ~isempty(fillCodes)
        y(ismember(y,fillCodes))=NaN;
    end
    y(~isfinite(y))=NaN;

    if numel(y)~=expected(s)
        error('Set %s contains %d rows; the manuscript requires %d observations.', ...
            nm,numel(y),expected(s));
    end

    consecutive = s>=3;
    if consecutive
        utc = parseUTCColumn(T,timeIdx,nm,numel(y));
        if any(isnat(utc))
            error('Set %s contains missing or unparseable UTC timestamps.',nm);
        end
        if numel(utc)>1 && any(diff(utc)~=hours(1))
            error('Set %s timestamps are not consecutive hourly observations.',nm);
        end
    else
        % The manuscript deliberately treats N/A as retained observation
        % sequences; their original retained timestamp mapping is unavailable.
        utc = NaT(numel(y),1,'TimeZone','UTC');
    end

    D(s).name=nm;
    D(s).y=y;
    D(s).utc=utc(:);
    D(s).sourceFile=fullPath;
    D(s).sourceSheet=sheetName;
    D(s).sourceColumn=string(T.Properties.VariableNames{yIdx});
    D(s).isConsecutive=consecutive;
end
end

function [T,fullPath,sheetName] = selectExcelTable(promptText)
[fileName,folder] = uigetfile({'*.xlsx;*.xls','Excel workbooks (*.xlsx, *.xls)'},promptText);
if isequal(fileName,0)
    error('Excel file selection was cancelled: %s.',promptText);
end
fullPath=fullfile(folder,fileName);
try
    sheets=sheetnames(fullPath);
catch
    sheets={};
end
if isempty(sheets)
    sheetName=1;
elseif numel(sheets)==1
    sheetName=sheets{1};
else
    [ix,ok]=listdlg('PromptString',sprintf('Choose worksheet in %s:',fileName), ...
        'SelectionMode','single','ListString',cellstr(string(sheets)), ...
        'ListSize',[320 260]);
    if ~ok, error('Worksheet selection was cancelled for %s.',fileName); end
    sheetName=sheets{ix};
end
try
    T=readtable(fullPath,'Sheet',sheetName,'TextType','string','VariableNamingRule','preserve');
catch
    try
        T=readtable(fullPath,'Sheet',sheetName,'TextType','string','PreserveVariableNames',true);
    catch ME
        error('Could not read %s (%s): %s',fileName,string(sheetName),ME.message);
    end
end
if isempty(T) || height(T)==0
    error('The selected worksheet is empty: %s (%s).',fileName,string(sheetName));
end
end

function idx = findTimeColumn(T)
v=lower(regexprep(string(T.Properties.VariableNames),'[^a-zA-Z0-9]',''));
preferred = ["timestamputc","timestamp","startutc","datetime","date","time","hour","year","doy"];
idx=[];
for q=1:numel(preferred)
    hit=find(v==preferred(q),1);
    if ~isempty(hit), idx=hit; return; end
end
for q=1:numel(v)
    if contains(v(q),"timestamp") || contains(v(q),"utc") || ...
            contains(v(q),"time") || v(q)=="hour" || v(q)=="date"
        idx=q; return;
    end
end
end

function idx = chooseMeasurementColumn(T,setName,timeIdx,variableDescription)
v=string(T.Properties.VariableNames);
vn=lower(regexprep(v,'[^a-zA-Z0-9]',''));
if strcmpi(variableDescription,'Kp')
    hit=find(vn=="kp",1);
    if ~isempty(hit), idx=hit; return; end
end
target=lower(regexprep(string(setName),'[^a-zA-Z0-9]',''));
if strcmpi(variableDescription,'solar-wind speed')
    hit=find(vn==("set"+target) | vn==target,1);
    if ~isempty(hit), idx=hit; return; end
    hit=find(contains(vn,"speed") | vn=="vkms" | vn=="v",1);
    if ~isempty(hit), idx=hit; return; end
end

candidate=[];
for q=1:width(T)
    if ~isempty(timeIdx) && q==timeIdx, continue; end
    raw=T{:,q};
    if isnumeric(raw) || islogical(raw)
        candidate(end+1)=q; %#ok<AGROW>
    else
        z=numericColumn(raw);
        if sum(isfinite(z))>=max(3,round(.5*numel(z)))
            candidate(end+1)=q; %#ok<AGROW>
        end
    end
end
if isempty(candidate)
    error('No numeric %s column was found in the selected worksheet.',variableDescription);
elseif numel(candidate)==1
    idx=candidate(1);
else
    labels=cellstr(v(candidate));
    [k,ok]=listdlg('PromptString',sprintf('Choose the %s column for Set %s:', ...
        variableDescription,setName),'SelectionMode','single', ...
        'ListString',labels,'ListSize',[360 260]);
    if ~ok, error('Measurement-column selection was cancelled for Set %s.',setName); end
    idx=candidate(k);
end
end

function y = numericColumn(raw)
if isnumeric(raw) || islogical(raw)
    y=double(raw(:));
else
    s=strtrim(string(raw(:)));
    s=replace(s,",",".");
    y=str2double(s);
end
end

function utc = parseUTCColumn(T,timeIdx,setName,n)
utc=NaT(n,1,'TimeZone','UTC');
base=datasetStartTime(setName);
if isempty(timeIdx)
    if ~isnat(base), utc=base+hours((0:n-1)'); end
    return;
end
raw=T{:,timeIdx};
if isdatetime(raw)
    utc=raw(:);
    if isempty(utc.TimeZone), utc.TimeZone='UTC'; else, utc.TimeZone='UTC'; end
    return;
end
if isnumeric(raw)
    if ~isnat(base)
        utc=base+hours(double(raw(:)));
    end
    return;
end

ss=strtrim(string(raw(:)));
for k=1:min(n,numel(ss))
    if ismissing(ss(k)) || strlength(ss(k))==0, continue; end
    s=char(ss(k));
    % ISO-like timestamps are parsed first.
    try
        utc(k)=datetime(s,'InputFormat',"yyyy-MM-dd'T'HH:mm:ss'Z'",'TimeZone','UTC');
        continue;
    catch
    end
    try
        utc(k)=datetime(s,'InputFormat','yyyy-MM-dd HH:mm:ss','TimeZone','UTC');
        continue;
    catch
    end
    % OMNI source workbooks store time as "year day-of-year hour".
    nums=regexp(s,'\d+','match');
    if numel(nums)>=3
        yy=str2double(nums{1}); doy=str2double(nums{2}); hh=str2double(nums{3});
        if isfinite(yy)&&isfinite(doy)&&isfinite(hh)&&doy>=1&&doy<=366&&hh>=0&&hh<=23
            utc(k)=datetime(yy,1,1,0,0,0,'TimeZone','UTC')+days(doy-1)+hours(hh);
        end
    elseif numel(nums)==1 && ~isnat(base)
        utc(k)=base+hours(str2double(nums{1}));
    end
end
if all(isnat(utc)) && ~isnat(base)
    utc=base+hours((0:n-1)');
end
end

function t = datasetStartTime(setName)
switch upper(string(setName))
    case "M", t=datetime(2026,1,1,0,0,0,'TimeZone','UTC');
    case "1", t=datetime(2017,1,1,0,0,0,'TimeZone','UTC');
    case "2", t=datetime(2017,5,1,0,0,0,'TimeZone','UTC');
    case "3", t=datetime(2017,9,1,0,0,0,'TimeZone','UTC');
    otherwise, t=NaT(1,1,'TimeZone','UTC');
end
end

function K = loadKpWorkbooksInteractive()
names={'M','1','2','3'};
expected=[2706 2880 2952 2928];
allTime=NaT(0,1,'TimeZone','UTC');
allKp=zeros(0,1);
allSet=strings(0,1);

for s=1:numel(names)
    nm=names{s};
    [T,fullPath,sheetName]=selectExcelTable( ...
        sprintf('Select the 3-hour Kp Excel workbook for Set %s',nm));
    timeIdx=findTimeColumn(T);
    kpIdx=chooseMeasurementColumn(T,nm,timeIdx,'Kp');
    kp=numericColumn(T{:,kpIdx});
    kp=kp(:);
    if any(~isfinite(kp))
        error('Kp workbook for Set %s contains missing or nonnumeric Kp values.',nm);
    end
    utc=parseUTCColumn(T,timeIdx,nm,numel(kp));
    if any(isnat(utc))
        error('Kp workbook for Set %s contains unparseable timestamps.',nm);
    end

    if numel(kp)==expected(s)
        % The supplied source workbooks store each 3-hour Kp value on
        % three successive hourly rows. Validate the triplets before thinning.
        if mod(numel(kp),3)~=0 || any(diff(utc)~=hours(1))
            error('Hourly Kp data for Set %s do not form complete consecutive 3-hour groups.',nm);
        end
        kg=reshape(kp,3,[]);
        if any(any(abs(kg-kg(1,:))>1e-10))
            error(['Kp values are not constant within every three-hour group in Set %s. ' ...
                'Please supply the original 3-hour Kp values.'],nm);
        end
        ix=1:3:numel(kp);
        kp=kp(ix);
        utc=utc(ix);
    elseif numel(kp)==expected(s)/3
        if numel(utc)>1 && any(diff(utc)~=hours(3))
            error('Three-hour Kp timestamps for Set %s are not spaced by exactly three hours.',nm);
        end
    else
        error('Kp workbook for Set %s contains %d rows; expected %d hourly or %d three-hour records.', ...
            nm,numel(kp),expected(s),expected(s)/3);
    end

    if max(kp)>9
        kp=kp/10; % GFZ source workbooks store Kp in tenths.
    end
    if any(kp<0 | kp>9)
        error('Kp values for Set %s are outside the standard 0-9 range.',nm);
    end
    if any(minute(utc)~=0 | second(utc)~=0 | mod(hour(utc),3)~=0)
        error('Kp records for Set %s must begin at 00, 03, 06, ..., 21 UTC.',nm);
    end

    fprintf('  Kp Set %s: %d three-hour records | %s | worksheet %s\n', ...
        nm,numel(kp),fullPath,string(sheetName));
    allTime=[allTime;utc(:)]; %#ok<AGROW>
    allKp=[allKp;kp(:)]; %#ok<AGROW>
    allSet=[allSet;repmat(string(nm),numel(kp),1)]; %#ok<AGROW>
end

[allTime,ord]=sort(allTime);
allKp=allKp(ord);
allSet=allSet(ord);
if numel(unique(allTime))~=numel(allTime)
    error('The four Kp workbooks contain duplicate UTC timestamps.');
end
K=table(allTime,allKp,allSet,'VariableNames',{'start_utc','kp','source_set'});
end

function tf = askYesNo(question,titleText,defaultYes)
if defaultYes, defaultChoice='Yes'; else, defaultChoice='No'; end
try
    a = questdlg(question,titleText,'Yes','No',defaultChoice);
    tf = strcmp(a,'Yes');
catch
    tf = defaultYes;
end
end

function R = resultTemplate()
R = struct('name','','y',[],'utc',[],'sourceFile','','sourceSheet','','sourceColumn','', ...
    'isConsecutive',false,'P',[],'starts',[],'controls',{{}},'H',[],'HY',[], ...
    'HI',[],'Hstarts',[],'Hoffset',[],'C1',[],'C1Jumps',table(), ...
    'fitMetrics',[],'heldMetrics',[],'degreeRows',table(),'continuityRows',table(), ...
    'fitTable',table(),'heldTable',table(),'validFitMask',[],'LAI',struct());
end

%% Core Bezier and classical fitting
function B = bernsteinBasis(t,d)
t = t(:);
B = zeros(numel(t),d+1);
for k=0:d
    B(:,k+1) = nchoosek(d,k).*t.^k.*(1-t).^(d-k);
end
end

function [pred,control] = fitBezier(xTrain,yTrain,degree,xEval,windowLength)
% Cached linear operators avoid repeating the same Bernstein least-squares
% factorization for every window and every held-out target.
persistent fitCache
if isempty(fitCache)
    fitCache=containers.Map('KeyType','char','ValueType','any');
end
xTrain=xTrain(:); yTrain=yTrain(:); xEval=xEval(:);
if numel(xTrain)~=numel(yTrain) || numel(xTrain)<degree+1
    pred=nan(size(xEval)); control=nan(degree+1,1); return;
end
key=sprintf('d%d_h%.12g_x%s_e%s',degree,windowLength, ...
    sprintf('%.12g,',xTrain),sprintf('%.12g,',xEval));
if isKey(fitCache,key)
    op=fitCache(key);
else
    Btrain=bernsteinBasis(xTrain/windowLength,degree);
    inside=xTrain>0 & xTrain<windowLength;
    nInside=sum(inside);
    if nInside<degree-1
        pred=nan(size(xEval)); control=nan(degree+1,1); return;
    end
    A=Btrain(inside,2:degree);
    nTrain=numel(xTrain);
    eFirst=zeros(1,nTrain); eFirst(1)=1;
    eLast=zeros(1,nTrain); eLast(end)=1;
    E=zeros(nInside,nTrain);
    E(:,inside)=eye(nInside);
    rhsMap=E-Btrain(inside,1)*eFirst-Btrain(inside,end)*eLast;
    controlMap=zeros(degree+1,nTrain);
    controlMap(1,:)=eFirst;
    controlMap(end,:)=eLast;
    controlMap(2:degree,:)=A\rhsMap;
    evalMap=bernsteinBasis(xEval/windowLength,degree)*controlMap;
    op=struct('ControlMap',controlMap,'EvalMap',evalMap);
    fitCache(key)=op;
end
control=op.ControlMap*yTrain;
pred=op.EvalMap*yTrain;
end

function pred = classicalFit(xTrain,yTrain,xEval,windowLength)
xTrain=xTrain(:); yTrain=yTrain(:); xEval=xEval(:);
support = [0;3;5;8];
if windowLength~=8
    error('The reduced-support classical methods are defined for the baseline 8-interval window.');
end
p = polyfit(xTrain,yTrain,1);
ys = polyval(p,support);
i0=find(xTrain==0,1); i1=find(xTrain==windowLength,1);
if isempty(i0)||isempty(i1)
    pred=nan(numel(xEval),4); return;
end
ys(1)=yTrain(i0); ys(end)=yTrain(i1);
lin = interp1(support,ys,xEval,'linear');
spl = spline(support,ys,xEval);
herm = pchip(support,ys,xEval);
lag = lagrangeEval(xEval,support,ys);
pred = [lin(:),spl(:),herm(:),lag(:)];
end


function pred=classicalFitOne(xTrain,yTrain,xEval,windowLength,methodIndex)
xTrain=xTrain(:); yTrain=yTrain(:); xEval=xEval(:);
support=[0;3;5;8];
p=polyfit(xTrain,yTrain,1);
ys=polyval(p,support);
i0=find(xTrain==0,1); i1=find(xTrain==windowLength,1);
if isempty(i0)||isempty(i1), pred=nan(numel(xEval),1); return; end
ys(1)=yTrain(i0); ys(end)=yTrain(i1);
switch methodIndex
    case 1, pred=interp1(support,ys,xEval,'linear');
    case 2, pred=spline(support,ys,xEval);
    case 3, pred=pchip(support,ys,xEval);
    case 4, pred=lagrangeEval(xEval,support,ys);
    otherwise, error('Unknown classical interpolation method.');
end
pred=pred(:);
end

function starts=validWindowStarts(y,h)
% Prefix-sum validity test avoids repeatedly scanning every window.
y=y(:);
candidates=(1:h:numel(y)-h)';
bad=[0;cumsum(~isfinite(y))];
keep=(bad(candidates+h+1)-bad(candidates))==0;
starts=candidates(keep);
end

function y = lagrangeEval(x,X,Y)
% Vectorized barycentric four-node Lagrange evaluation.
x=x(:); X=X(:)'; Y=Y(:)';
m=numel(X);
w=ones(1,m);
for j=1:m
    jj=[1:j-1,j+1:m];
    w(j)=1/prod(X(j)-X(jj));
end
DX=x-X;
exact=abs(DX)<1e-12;
hasExact=any(exact,2);
y=nan(size(x));
if any(~hasExact)
    q=~hasExact;
    terms=w./DX(q,:);
    y(q)=sum(terms.*Y,2)./sum(terms,2);
end
for j=1:m
    q=exact(:,j);
    y(q)=Y(j);
end
end

function [P,starts,C] = fitAll(y,h,degrees,includeClassical)
y=y(:); n=numel(y);
if isempty(degrees), degrees=[]; end
nClass=4*logical(includeClassical);
P=nan(n,numel(degrees)+nClass);
starts=validWindowStarts(y,h);
C=cell(1,numel(degrees));
for j=1:numel(degrees), C{j}=nan(numel(starts),degrees(j)+1); end
x=(0:h)';
for q=1:numel(starts)
    a=starts(q); z=y(a:a+h);
    for j=1:numel(degrees)
        [p,c]=fitBezier(x,z,degrees(j),x,h);
        P(a:a+h,j)=p;
        C{j}(q,:)=c(:)';
    end
    if includeClassical
        P(a:a+h,numel(degrees)+(1:4))=classicalFit(x,z,x,h);
    end
end
end

function [H,Y,idx,windowStart,offset] = heldAll(y,starts,h,degrees,includeClassical)
y=y(:); nMeth=numel(degrees)+4*logical(includeClassical);
nRows=numel(starts)*(h-1);
H=nan(nRows,nMeth); Y=nan(nRows,1); idx=nan(nRows,1);
windowStart=nan(nRows,1); offset=nan(nRows,1);
x=(0:h)'; r=0;
for a=starts(:)'
    z=y(a:a+h);
    for k=1:h-1
        r=r+1;
        keep=(x~=k);
        Y(r)=z(k+1);
        idx(r)=a+k;
        windowStart(r)=a-1;
        offset(r)=k;
        for j=1:numel(degrees)
            H(r,j)=fitBezier(x(keep),z(keep),degrees(j),k,h);
        end
        if includeClassical
            c=classicalFit(x(keep),z(keep),k,h);
            H(r,numel(degrees)+(1:4))=c;
        end
    end
end
end

function M = metricVector(y,p)
y=y(:); p=p(:);
ok=isfinite(y)&isfinite(p);
y=y(ok); p=p(ok);
if isempty(y)
    M=[0 NaN NaN NaN NaN]; return;
end
e=y-p;
nz=(y~=0);
if any(nz), mape=100*mean(abs(e(nz)./y(nz))); else, mape=NaN; end
sst=sum((y-mean(y)).^2);
if sst>0, r2=1-sum(e.^2)/sst; else, r2=NaN; end
M=[numel(y),sqrt(mean(e.^2)),mean(abs(e)),mape,r2];
end

function M = metricsByColumn(y,P)
M=zeros(size(P,2),5);
for j=1:size(P,2), M(j,:)=metricVector(y,P(:,j)); end
end

function T = makeFitTable(R,methodNames)
C=cell(0,9);
for j=1:numel(methodNames)
    m=R.fitMetrics(j,:);
    C(end+1,:)={R.name,'Fit',methodNames{j},m(1),m(2),m(3),m(4),m(5),R.starts(1)}; %#ok<AGROW>
end
T=cell2table(C,'VariableNames',{'Set','Evaluation','Method','N','RMSE','MAE','MAPE_percent','R2','FirstWindowStartIndex'});
end

function T = makeHeldTable(R,methodNames)
C=cell(0,9);
for j=1:numel(methodNames)
    m=R.heldMetrics(j,:);
    C(end+1,:)={R.name,'Held-out',methodNames{j},m(1),m(2),m(3),m(4),m(5),numel(R.starts)}; %#ok<AGROW>
end
T=cell2table(C,'VariableNames',{'Set','Evaluation','Method','N','RMSE','MAE','MAPE_percent','R2','CompleteWindows'});
end

function T = makeDescriptiveTable(R)
C=cell(0,8);
for s=1:numel(R)
    y=R(s).y; z=y(isfinite(y));
    C(end+1,:)={R(s).name,numel(y),min(z),max(z),median(z),mean(z),std(z,0),sum(~isfinite(y))}; %#ok<AGROW>
end
T=cell2table(C,'VariableNames',{'Set','Observations','Minimum_km_s','Maximum_km_s','Median_km_s','Mean_km_s','SampleSD_km_s','Missing'});
end

function T = makeBezierMainTable(R)
C=cell(0,7);
for s=1:numel(R)
    for j=1:3
        m=R(s).fitMetrics(j,:);
        degreeLabels={'Quadratic','Cubic','Quartic'};
        C(end+1,:)={R(s).name,degreeLabels{j},m(2),m(3),m(4),m(5),m(1)}; %#ok<AGROW>
    end
end
T=cell2table(C,'VariableNames',{'Set','BezierDegree','RMSE_km_s','MAE_km_s','MAPE_percent','R2','N'});
end

function T = makeClassicalMainTable(R)
C=cell(0,7);
names={'Linear','Cubic spline','Hermite','Lagrange'};
for s=1:numel(R)
    for j=1:4
        m=R(s).fitMetrics(5+j,:);
        C(end+1,:)={R(s).name,names{j},m(2),m(3),m(4),m(5),m(1)}; %#ok<AGROW>
    end
end
T=cell2table(C,'VariableNames',{'Set','Method','RMSE_km_s','MAE_km_s','MAPE_percent','R2','N'});
end

function rows = degreeSensitivityRows(R,h,degrees)
C=cell(0,8);
for j=1:numel(degrees)
    d=degrees(j); pcol=j;
    vals=[]; preds=[];
    for q=1:numel(R.starts)
        a=R.starts(q); idx=a+(1:h-1);
        vals=[vals;R.y(idx)]; %#ok<AGROW>
        preds=[preds;R.P(idx,pcol)]; %#ok<AGROW>
    end
    ok=isfinite(vals)&isfinite(preds); vals=vals(ok); preds=preds(ok);
    n=numel(vals); pcount=numel(R.starts)*(d-1); df=n-pcount;
    if df>0 && n>1 && sum((vals-mean(vals)).^2)>0
        adj=1-(sum((vals-preds).^2)/df)/(sum((vals-mean(vals)).^2)/(n-1));
    else
        adj=NaN;
    end
    fit=R.fitMetrics(pcol,:); held=R.heldMetrics(pcol,:);
    C(end+1,:)={R.name,d,d-1,df,fit(2),adj,held(2),held(1)}; %#ok<AGROW>
end
rows=cell2table(C,'VariableNames',{'Set','Degree','FreeInteriorControls','ResidualDF','FitRMSE','ConditionalAdjustedR2','HeldRMSE','HeldN'});
end

function T = makeDegreeSummaryTable(R)
C=cell(0,6);
for s=1:numel(R)
    dr=R(s).degreeRows;
    fit4=dr.FitRMSE(dr.Degree==4);
    fit6=dr.FitRMSE(dr.Degree==6);
    [bestRMSE,ix]=min(dr.HeldRMSE);
    held6=dr.HeldRMSE(dr.Degree==6);
    C(end+1,:)={R(s).name,fit4,fit6,dr.Degree(ix),bestRMSE,held6}; %#ok<AGROW>
end
T=cell2table(C,'VariableNames',{'Set','Degree4FitRMSE','Degree6FitRMSE','BestHeldDegree','BestHeldRMSE','Degree6HeldRMSE'});
end

%% Continuity and LAI
function C = knotJumps(starts,controls,degree,h)
C=table();
if numel(starts)<2 || isempty(controls), return; end
rows=cell(0,3);
for k=1:numel(starts)-1
    if starts(k+1)-starts(k)~=h, continue; end
    left=degree*(controls(k,end)-controls(k,end-1))/h;
    right=degree*(controls(k+1,2)-controls(k+1,1))/h;
    rows(end+1,:)={starts(k+1)-1,right-left,abs(right-left)}; %#ok<AGROW>
end
if ~isempty(rows)
    C=cell2table(rows,'VariableNames',{'KnotIndex','SignedDerivativeJump','AbsoluteDerivativeJump'});
end
end

function [p,J] = continuousCubic(y,starts,h)
% Endpoint-interpolating C1 cubic Hermite model. Shared knot derivatives are
% estimated jointly by least squares within each contiguous run of windows.
y=y(:); p=nan(size(y));
jumpRows=cell(0,3);
if isempty(starts)
    J=cell2table(jumpRows,'VariableNames',{'KnotIndex','SignedDerivativeJump','AbsoluteDerivativeJump'});
    return;
end
breaks=[1;find(diff(starts)~=h)+1;numel(starts)+1];
t=(0:h)'/h;
h00=2*t.^3-3*t.^2+1;
h10=t.^3-2*t.^2+t;
h01=-2*t.^3+3*t.^2;
h11=t.^3-t.^2;
for b=1:numel(breaks)-1
    ids=breaks(b):breaks(b+1)-1;
    st=starts(ids); nw=numel(st);
    if nw==0, continue; end
    A=spalloc((h-1)*nw,nw+1,2*(h-1)*nw);
    rhs=zeros((h-1)*nw,1);
    for j=1:nw
        rr=(j-1)*(h-1)+(1:h-1);
        z=y(st(j):st(j)+h);
        A(rr,j)=h*h10(2:h);
        A(rr,j+1)=h*h11(2:h);
        rhs(rr)=z(2:h)-h00(2:h)*z(1)-h01(2:h)*z(end);
    end
    slopes=A\rhs;
    for j=1:nw
        a=st(j); z=y(a:a+h);
        p(a:a+h)=h00*z(1)+h01*z(end)+h*h10*slopes(j)+h*h11*slopes(j+1);
        if j<nw
            % Reconstruct the left/right endpoint derivatives independently
            % from their cubic Bezier ordinates, then report the numerical jump.
            m=slopes(j+1);
            leftP2=z(end)-h*m/3;
            leftDerivative=3*(z(end)-leftP2)/h;
            zNext=y(st(j+1):st(j+1)+h);
            rightP1=zNext(1)+h*m/3;
            rightDerivative=3*(rightP1-zNext(1))/h;
            signedJump=rightDerivative-leftDerivative;
            jumpRows(end+1,:)={st(j+1)-1,signedJump,abs(signedJump)}; %#ok<AGROW>
        end
    end
end
J=cell2table(jumpRows,'VariableNames',{'KnotIndex','SignedDerivativeJump','AbsoluteDerivativeJump'});
end


function dw = durbinWatsonNoBridge(residual)
r=residual(:); valid=isfinite(r);
den=sum(r(valid).^2);
if sum(valid)<2 || den==0, dw=NaN; return; end
adj=valid(1:end-1)&valid(2:end);
d=diff(r);
dw=sum(d(adj).^2)/den;
end

function T = continuityRows(R,h,degrees)
C=cell(0,8);
for j=1:numel(degrees)
    deg=degrees(j);
    J=knotJumps(R.starts,R.controls{j},deg,h);
    if isempty(J), absj=[]; else, absj=J.AbsoluteDerivativeJump; end
    m=metricVector(R.y,R.P(:,j));
    C(end+1,:)={R.name,deg,height(J),m(2),durbinWatsonNoBridge(R.y-R.P(:,j)), ...
        safeQuantile(absj,.50),safeQuantile(absj,.95),safeMax(absj)}; %#ok<AGROW>
end
J=R.C1Jumps;
nJoin=height(J);
if isempty(J), absj=[]; else, absj=J.AbsoluteDerivativeJump; end
m=metricVector(R.y,R.C1);
C(end+1,:)={R.name,'C1 cubic',nJoin,m(2),durbinWatsonNoBridge(R.y-R.C1), ...
    safeQuantile(absj,.50),safeQuantile(absj,.95),safeMax(absj)}; %#ok<AGROW>
T=cell2table(C,'VariableNames',{'Set','Model','Joins','RMSE','DurbinWatson','MedianAbsJump','P95AbsJump','MaximumAbsJump'});
end

function [L,starts,Q,X,scores,classes,maxChange] = localActivity(y,blockLength)
y=y(:); starts=(1:blockLength:numel(y)-blockLength+1)';
X=zeros(0,4); maxChange=zeros(0,2); validStarts=[];
for q=1:numel(starts)
    a=starts(q); z=y(a:a+blockLength-1);
    if any(~isfinite(z)), continue; end
    dd=diff(z);
    [v,k]=max(dd);
    validStarts(end+1,1)=a; %#ok<AGROW>
    X(end+1,:)=[std(z,0),max(z)-min(z),mean(abs(dd)),max(abs(dd))]; %#ok<AGROW>
    if v>0
        maxChange(end+1,:)=[v,a+k-1]; %#ok<AGROW>
    else
        maxChange(end+1,:)=[0,NaN]; %#ok<AGROW>
    end
end
starts=validStarts;
if isempty(X)
    L=[]; Q=nan(3,4); scores=[]; classes=[]; maxChange=zeros(0,2); return;
end
Q=quantileLinear(X,[.25 .50 .75]);
scores=scoreBy(X,Q);
L=mean(scores,2);
classes=classifyLAI(L,[.75 1.50 2.25]);
end

function Q=quantileLinear(X,p)
% Linear interpolation at (n-1)*p, equivalent to the common type-7 rule.
if isvector(X), X=X(:); end
X=sort(X,1,'MissingPlacement','last');
n=size(X,1); p=p(:);
Q=nan(numel(p),size(X,2));
for j=1:size(X,2)
    v=X(:,j); v=v(isfinite(v)); nn=numel(v);
    if nn==0, continue; end
    for k=1:numel(p)
        pos=1+(nn-1)*p(k); lo=floor(pos); hi=ceil(pos);
        Q(k,j)=v(lo)+(pos-lo)*(v(hi)-v(lo));
    end
end
end

function S=scoreBy(X,Q)
S=zeros(size(X));
for k=1:size(Q,1)
    S=S+(X>=Q(k,:));
end
end

function cls=classifyLAI(x,bounds)
cls=sum(x(:)>=bounds(:)',2);
end

function r=averageRanks(x)
x=x(:); [v,ord]=sort(x); r=zeros(size(x)); n=numel(x); k=1;
while k<=n
    j=k;
    while j<n && v(j+1)==v(k), j=j+1; end
    r(ord(k:j))=(k+j)/2;
    k=j+1;
end
end

function rho=spearmanRank(x,y)
x=x(:); y=y(:); ok=isfinite(x)&isfinite(y); x=x(ok); y=y(ok);
if numel(x)<3 || std(x)==0 || std(y)==0, rho=NaN; return; end
rx=averageRanks(x); ry=averageRanks(y);
c=corrcoef(rx,ry); rho=c(1,2);
end

function [pcaWeights,pcaVariance,corrPearson,corrSpearman] = componentPCA(X)
corrPearson=corrcoef(X);
rankX=zeros(size(X));
for j=1:size(X,2), rankX(:,j)=averageRanks(X(:,j)); end
corrSpearman=corrcoef(rankX);
[V,E]=eig(corrPearson);
[ev,k]=max(diag(E));
w=V(:,k);
if sum(w)<0, w=-w; end
if any(w<0)
    warning('A negative PC1 coefficient was encountered; absolute coefficients are used for positive normalized LAI weights.');
    w=abs(w);
end
pcaWeights=w/sum(w);
pcaVariance=100*ev/trace(corrPearson);
end

function row=compareLAI(a,L,baseClasses,bounds)
cl=classifyLAI(a,bounds);
agree=100*mean(cl==baseClasses);
den=sum(cl==3 | baseClasses==3);
if den==0, jac=NaN; else, jac=sum(cl==3 & baseClasses==3)/den; end
row=[spearmanRank(a,L),agree,jac];
end

function S = sensitivityScenarios(R)
X=R.LAI.components; L=R.LAI.values; baseClass=R.LAI.classes; Q=R.LAI.quartiles; score=R.LAI.scores;
rows=cell(0,6); baseBounds=[.75 1.50 2.25];
for j=1:4
    w=ones(4,1); w(j)=2; w=w/sum(w);
    met=compareLAI(score*w,L,baseClass,baseBounds);
    rows(end+1,:)={R.name,sprintf('Double_component_%d',j),met(1),met(2),met(3),'Double weight'}; %#ok<AGROW>
    w=ones(4,1); w(j)=0; w=w/sum(w);
    met=compareLAI(score*w,L,baseClass,baseBounds);
    rows(end+1,:)={R.name,sprintf('Omit_component_%d',j),met(1),met(2),met(3),'Omit component'}; %#ok<AGROW>
end
[w,~,~,~]=componentPCA(X);
met=compareLAI(score*w,L,baseClass,baseBounds);
rows(end+1,:)={R.name,'PCA_weighted',met(1),met(2),met(3),'PCA weights'}; %#ok<AGROW>
quantileSets={ [.20 .50 .80], [.30 .50 .70] };
for q=1:2
    qv=quantileLinear(X,quantileSets{q});
    qscore=mean(scoreBy(X,qv),2);
    met=compareLAI(qscore,L,baseClass,baseBounds);
    if q==1, tag='Quantile_20_50_80'; else, tag='Quantile_30_50_70'; end
    rows(end+1,:)={R.name,tag,met(1),met(2),met(3),'Component thresholds'}; %#ok<AGROW>
end
for shift=[-.125 .125]
    met=compareLAI(L,L,baseClass,baseBounds+shift);
    rows(end+1,:)={R.name,sprintf('ClassBoundary_%+.3f',shift),met(1),met(2),met(3),'Class boundaries'}; %#ok<AGROW>
end
S=cell2table(rows,'VariableNames',{'Set','Scenario','Spearman','ClassAgreementPercent','VeryHighJaccard','Group'});
end

function T=makeLAICountTable(R)
C=cell(0,5);
classNames={'Low','Moderate','High','Very high'};
intervals={'0.00–<0.75','0.75–<1.50','1.50–<2.25','2.25–3.00'};
for s=1:numel(R)
    cls=R(s).LAI.classes;
    counts=accumarray(cls+1,1,[4 1]);
    n=sum(counts);
    for j=1:4
        C(end+1,:)={R(s).name,classNames{j},intervals{j},counts(j),100*counts(j)/n}; %#ok<AGROW>
    end
    C(end+1,:)={R(s).name,'Total','—',n,100.0}; %#ok<AGROW>
end
T=cell2table(C,'VariableNames',{'Set','LAIClass','LAIInterval','Segments','Proportion_percent'});
end


function T=makeLAICountSummaryTable(R)
C=cell(0,6);
for s=1:numel(R)
    cls=R(s).LAI.classes;
    counts=accumarray(cls+1,1,[4 1]);
    C(end+1,:)={R(s).name,numel(cls),counts(1),counts(2),counts(3),counts(4)}; %#ok<AGROW>
end
T=cell2table(C,'VariableNames',{'Set','ValidBlocks','Low','Moderate','High','VeryHigh'});
end

function T=makeTopActivityTable(R)
C=cell(0,7);
if isempty(R.LAI) || isempty(R.LAI.values), T=cell2table(C,'VariableNames',{'Rank','BlockInterval_UTC','IncreaseInterval_UTC','SpeedTransition_km_s','PositiveIncrease_km_s','LAI','BlockStartIndex'}); return; end
M=R.LAI.maxChange; L=R.LAI.values; st=R.LAI.starts;
[~,ord]=sortrows([-M(:,1),st],[1 2]);
n=min(10,numel(ord));
for q=1:n
    k=ord(q); a=st(k); ix=M(k,2);
    if ~isfinite(ix) || M(k,1)<=0, continue; end
    t0=R.utc(a); t1=R.utc(a+7);
    t2=R.utc(ix); t3=R.utc(ix+1);
    blockLabel=sprintf('%s | %02d:00–%02d:00',formatUTCDate(t0),hour(t0),hour(t1));
    changeLabel=sprintf('%02d:00–%02d:00',hour(t2),hour(t3));
    transition=sprintf('%.0f → %.0f',R.y(ix),R.y(ix+1));
    C(end+1,:)={q,blockLabel,changeLabel,transition,M(k,1),L(k),a-1}; %#ok<AGROW>
end
T=cell2table(C,'VariableNames',{'Rank','BlockInterval_UTC','IncreaseInterval_UTC','SpeedTransition_km_s','PositiveIncrease_km_s','LAI','BlockStartIndex'});
end

function T=makeLAISensitivitySummary(R)
C=cell(0,8);
groups={'Double weight','Omit component','PCA weights','Component thresholds','Class boundaries'};
for s=1:numel(R)
    S=sensitivityScenarios(R(s));
    for g=1:numel(groups)
        ix=strcmp(S.Group,groups{g});
        if ~any(ix), continue; end
        C(end+1,:)={R(s).name,groups{g},min(S.Spearman(ix)),max(S.Spearman(ix)), ...
            min(S.ClassAgreementPercent(ix)),max(S.ClassAgreementPercent(ix)), ...
            min(S.VeryHighJaccard(ix)),max(S.VeryHighJaccard(ix))}; %#ok<AGROW>
    end
end
T=cell2table(C,'VariableNames',{'Set','PerturbationGroup','SpearmanMin','SpearmanMax','AgreementMin_percent','AgreementMax_percent','VeryHighJaccardMin','VeryHighJaccardMax'});
end

function T=makeComponentCorrelationTable(R)
labels={'STD','Range','MASD','MaxAD'};
pairs=[1 2;1 3;1 4;2 3;2 4;3 4];
pairLabels={'STD–Range';'STD–MASD';'STD–MaxAD';'Range–MASD';'Range–MaxAD';'MASD–MaxAD'};
C=cell(6,9);
for q=1:6
    C{q,1}=pairLabels{q};
    for s=1:numel(R)
        X=R(s).LAI.components;
        [~,~,rp,rs]=componentPCA(X);
        a=pairs(q,1); b=pairs(q,2);
        C{q,2+(s-1)*2}=rp(a,b);
        C{q,3+(s-1)*2}=rs(a,b);
    end
end
T=cell2table(C,'VariableNames',{'Pair','SetM_Pearson','SetM_Spearman','Set1_Pearson','Set1_Spearman', ...
    'Set2_Pearson','Set2_Spearman','Set3_Pearson','Set3_Spearman'});
end

function T=makePCATable(R)
C=cell(0,6);
for s=1:numel(R)
    [w,v]=componentPCA(R(s).LAI.components);
    C(end+1,:)=[{R(s).name,v},num2cell(w(:)')]; %#ok<AGROW>
end
T=cell2table(C,'VariableNames',{'Set','PC1VariancePercent','STDWeight','RangeWeight','MASDWeight','MaxADWeight'});
end

function T=makeLAIQuartileTable(R)
C=cell(0,5); labels={'STD','Range','MASD','MaxAD'};
for s=1:numel(R)
    Q=R(s).LAI.quartiles;
    for j=1:4
        C(end+1,:)={R(s).name,labels{j},Q(1,j),Q(2,j),Q(3,j)}; %#ok<AGROW>
    end
end
T=cell2table(C,'VariableNames',{'Set','Component','Q1','Median','Q3'});
end

function L=calculateLAI(y,blockLength)
[L.values,L.starts,L.quartiles,L.components,L.scores,L.classes,L.maxChange]=localActivity(y,blockLength);
L.blockLength=blockLength;
end

function T=makeCoverageTable(R)
C=cell(0,6);
for s=1:numel(R)
    C(end+1,:)={R(s).name,numel(R(s).y),sum(~isfinite(R(s).y)), ...
        numel(R(s).starts),sum(isfinite(R(s).P(:,1))),numel(R(s).HY)}; %#ok<AGROW>
end
T=cell2table(C,'VariableNames',{'Set','Records','Missing','CompleteWindows','FitPositions','WithheldTargets'});
end

function [Tfit,Theld] = makeAdditionalPeriodTables(R)
Cfit=cell(0,7); Cheld=cell(0,7);
labels={'Bezier 2','Bezier 3','Bezier 4','Linear','Lagrange / spline','Hermite'};
cols=[1 2 3 6 7 8];
for s=1:numel(R)
    for j=1:numel(cols)
        m=R(s).fitMetrics(cols(j),:);
        Cfit(end+1,:)={R(s).name,labels{j},m(2),m(3),m(4),m(5),m(1)}; %#ok<AGROW>
        mh=R(s).heldMetrics(cols(j),:);
        Cheld(end+1,:)={R(s).name,labels{j},mh(2),mh(3),mh(4),mh(5),mh(1)}; %#ok<AGROW>
    end
end
Tfit=cell2table(Cfit,'VariableNames',{'Set','Method','RMSE_km_s','MAE_km_s','MAPE_percent','R2','N'});
Theld=cell2table(Cheld,'VariableNames',{'Set','Method','RMSE_km_s','MAE_km_s','MAPE_percent','R2','N'});
end

function T=makeLongWindowTable(R)
C=cell(0,10);
for s=1:numel(R)
    y=R(s).y;
    for h=[12 24]
        [P,starts]=fitAll(y,h,2:4,false);
        for j=1:3
            m=metricVector(y,P(:,j));
            C(end+1,:)={R(s).name,h,h+1,numel(starts),j+1,m(1),m(2),m(3),m(4),m(5)}; %#ok<AGROW>
        end
    end
end
T=cell2table(C,'VariableNames',{'Set','WindowHours','ObservationsPerWindow','CompleteWindows','Degree','N','RMSE_km_s','MAE_km_s','MAPE_percent','R2'});
end

function T=makeWindowSensitivityTable(R,hBase)
C=cell(0,9);
for h=[hBase 12 24]
    [P,starts]=fitAll(R.y,h,2:4,false);
    for j=1:3
        m=metricVector(R.y,P(:,j));
        C(end+1,:)={h,h+1,numel(starts),j+1,m(1),m(2),m(3),m(4),m(5)}; %#ok<AGROW>
    end
end
T=cell2table(C,'VariableNames',{'WindowHours','ObservationsPerWindow','CompleteWindows','Degree','N','RMSE_km_s','MAE_km_s','MAPE_percent','R2'});
end

function [T5a,T5b]=makeDegreeAppendixTables(R)
C1=cell(0,8); C2=cell(0,8);
for s=1:numel(R)
    for k=1:height(R(s).degreeRows)
        r=R(s).degreeRows(k,:);
        row={R(s).name,r.Degree,r.FreeInteriorControls,r.ResidualDF,r.FitRMSE,r.ConditionalAdjustedR2,r.HeldRMSE,r.HeldN};
        if s<=3, C1(end+1,:)=row; else, C2(end+1,:)=row; end %#ok<AGROW>
    end
end
T5a=cell2table(C1,'VariableNames',{'Set','Degree','FreeInteriorControls','ResidualDF','FitRMSE','ConditionalAdjustedR2','HeldRMSE','HeldN'});
T5b=cell2table(C2,'VariableNames',{'Set','Degree','FreeInteriorControls','ResidualDF','FitRMSE','ConditionalAdjustedR2','HeldRMSE','HeldN'});
end

function T=makeContinuityAppendixTable(R)
C=cell(0,8);
for s=1:numel(R)
    for j=1:3
        r=R(s).continuityRows(j,:);
        C(end+1,:)={R(s).name,j+1,r.Joins,r.MedianAbsJump,r.P95AbsJump,r.MaximumAbsJump,r.DurbinWatson,r.RMSE}; %#ok<AGROW>
    end
    r=R(s).continuityRows(4,:);
    C(end+1,:)={R(s).name,'C1',r.Joins,r.MedianAbsJump,r.P95AbsJump,r.MaximumAbsJump,r.DurbinWatson,r.RMSE}; %#ok<AGROW>
end
T=cell2table(C,'VariableNames',{'Set','DegreeOrC1','Joins','MedianAbsJump','P95AbsJump','MaximumAbsJump','DurbinWatson','RMSE'});
end

function T=makeResidualContinuitySummary(R)
C=cell(0,7);
for s=1:numel(R)
    for j=[2 3 4] % cubic, quartic and C1 cubic row indices in continuityRows
        r=R(s).continuityRows(j,:);
        if j==2, model='C0 cubic'; elseif j==3, model='C0 quartic'; else, model='C1 cubic'; end
        C(end+1,:)={R(s).name,model,r.RMSE,r.DurbinWatson,r.MedianAbsJump,r.P95AbsJump,r.MaximumAbsJump}; %#ok<AGROW>
    end
end
T=cell2table(C,'VariableNames',{'Set','Model','RMSE_km_s','DurbinWatson','MedianAbsJump_km_s_per_hour','P95AbsJump','MaximumAbsJump'});
end

function T=makeMATLABStorageTable(R)
nW=numel(R.starts);
labels={'Bezier 2','Bezier 3','Bezier 4','Bezier 5','Bezier 6','Linear','Cubic spline','Hermite','Lagrange','C1 cubic'};
C=cell(0,5);
for d=2:6
    nParam=nW*(d-1); nStored=nW*d+2;
    C(end+1,:)={labels{d-1},nParam,nStored,nParam*8/1024,nStored*8/1024}; %#ok<AGROW>
end
for j=1:4
    nParam=2*nW; nStored=3*nW+2;
    C(end+1,:)={labels{5+j},nParam,nStored,nParam*8/1024,nStored*8/1024}; %#ok<AGROW>
end
nParam=nW+1; nStored=2*(nW+1)+1;
C(end+1,:)={labels{10},nParam,nStored,nParam*8/1024,nStored*8/1024};
T=cell2table(C,'VariableNames',{'Method','FittedParameterCount','StoredScalars','ParameterStorageKiB','ModelStorageKiB'});
end


function T=makeCalibrationOffsetTable(R)
C=cell(0,6);
for d=[3 4]
    col=d-1; base=metricVector(R.y,R.P(:,col));
    for delta=[-.05 -.03 -.01 .01 .03 .05]
        scale=1+delta;
        C(end+1,:)={R.name,d,delta,abs(scale)*base(2),base(4),base(5)}; %#ok<AGROW>
    end
end
T=cell2table(C,'VariableNames',{'Set','Degree','CommonMultiplicativeOffset','ScaledRMSE_km_s','UnchangedMAPE_percent','UnchangedR2'});
end

%% Bootstrap and perturbation analyses
function T=makeClassicalBootstrapTable(R,nRep,seed)
stream=RandStream('mt19937ar','Seed',seed);
C=cell(0,5);
methodNames={'Linear','Cubic spline','Hermite','Lagrange','Hermite minus Lagrange'};
for s=1:numel(R)
    y=R(s).y; starts=R(s).starts; nW=numel(starts);
    if nW<4, continue; end
    % Each window contributes offsets 1:8; the initial observation is one
    % additional shared-endpoint zero residual in the pooled evaluation grid.
    E=zeros(nW,4);
    for j=1:nW
        ii=starts(j)+(1:8);
        E(j,:)=sum((y(ii)-R(s).P(ii,6:9)).^2,1);
    end
    Z=zeros(nRep,5);
    for b=1:nRep
        nRun=ceil(nW/4);
        runStarts=randi(stream,nW-3,nRun,1);
        ids=reshape((runStarts+(0:3))',[],1);
        ids=ids(1:nW);
        rmse=sqrt(sum(E(ids,:),1)/(8*nW+1));
        Z(b,1:4)=rmse;
        Z(b,5)=rmse(3)-rmse(4);
    end
    point=R(s).fitMetrics(6:9,2);
    pointDiff=point(3)-point(4);
    for j=1:4
        q=quantileLinear(Z(:,j),[.025 .975]);
        C(end+1,:)={R(s).name,methodNames{j},point(j),q(1),q(2)}; %#ok<AGROW>
    end
    q=quantileLinear(Z(:,5),[.025 .975]);
    C(end+1,:)={R(s).name,methodNames{5},pointDiff,q(1),q(2)}; %#ok<AGROW>
end
T=cell2table(C,'VariableNames',{'Set','MethodOrDifference','Estimate','Lower95','Upper95'});
end

function O=bezierFitOperator(n,starts,h,degree)
% Sparse linear operator mapping the original series to its fitted Bezier grid.
B=bernsteinBasis((0:h)'/h,degree);
A=B(2:h,2:degree);
E=[zeros(h-1,1),eye(h-1),zeros(h-1,1)];
C=zeros(degree+1,h+1);
C(1,1)=1; C(end,end)=1;
C(2:degree,:)=A\(E-B(2:h,1)*C(1,:)-B(2:h,end)*C(end,:));
local=B*C;
local(1,:)=0; local(1,1)=1;
local(end,:)=0; local(end,end)=1;
O=sparse(n,n);
for q=1:numel(starts)
    a=starts(q); ii=a:a+h;
    O(ii,ii)=local;
end
end

function [TA9a,TA9b]=makePerturbationTables(R,nRep,seed)
stream=RandStream('mt19937ar','Seed',seed);
Ca=cell(0,10); Cb=cell(0,10);
for s=1:numel(R)
    y=R(s).y(:); starts=R(s).starts(:);
    if isempty(starts), continue; end
    clean=y; clean(~isfinite(clean))=0;
    mask=isfinite(R(s).P(:,1));
    Op3=bezierFitOperator(numel(y),starts,8,3);
    Op4=bezierFitOperator(numel(y),starts,8,4);
    base3=Op3*clean; base4=Op4*clean;
    for sig=[.01 .03 .05]
        noise=randn(stream,numel(y),nRep);
        Y=clean.*(1+sig*noise);
        F3=Op3*Y; F4=Op4*Y;
        rmse3=sqrt(mean((F3(mask,:)-Y(mask,:)).^2,1))';
        rmse4=sqrt(mean((F4(mask,:)-Y(mask,:)).^2,1))';
        disp3=sqrt(mean((F3(mask,:)-base3(mask)).^2,1))';
        disp4=sqrt(mean((F4(mask,:)-base4(mask)).^2,1))';
        for deg=3:4
            if deg==3, rr=rmse3; dd=disp3; else, rr=rmse4; dd=disp4; end
            qr=quantileLinear(rr,[.025 .50 .975]);
            qd=quantileLinear(dd,[.025 .50 .975]);
            row={R(s).name,sig,deg,qr(2),qr(1),qr(3),qd(2),qd(1),qd(3),nRep};
            if s<=3, Ca(end+1,:)=row; else, Cb(end+1,:)=row; end %#ok<AGROW>
        end
    end
end
headers={'Set','RelativeSD','Degree','RMSE_Median','RMSE_Lower95','RMSE_Upper95', ...
    'Displacement_Median','Displacement_Lower95','Displacement_Upper95','Replicates'};
TA9a=cell2table(Ca,'VariableNames',headers);
TA9b=cell2table(Cb,'VariableNames',headers);
end

%% Paired Hermite-Lagrange Wilcoxon diagnostic
function T=makeWilcoxonTable(R)
C=cell(0,7); pvals=nan(numel(R),1);
for s=1:numel(R)
    starts=R(s).starts; y=R(s).y; P=R(s).P;
    diffs=[];
    for j=1:4:numel(starts)-3
        ss=starts(j:j+3);
        if any(diff(ss)~=8), continue; end
        ii=(ss(1)+1):(ss(end)+8); % 32 new positions; first shared endpoint omitted
        d=mean((y(ii)-P(ii,8)).^2-(y(ii)-P(ii,9)).^2);
        if isfinite(d), diffs(end+1,1)=d; end %#ok<AGROW>
    end
    [W,p]=wilcoxonSignedRankAsymptotic(diffs);
    pvals(s)=p;
    C(end+1,:)={R(s).name,numel(diffs),median(diffs),W,p,NaN,mean(diffs)}; %#ok<AGROW>
end
holm=holmAdjust(pvals);
for s=1:size(C,1), C{s,6}=holm(s); end
T=cell2table(C,'VariableNames',{'Set','CompleteGroups','MedianMSEDifference','WStatistic','NominalP','HolmAdjustedP','MeanMSEDifference'});
end

function [W,p]=wilcoxonSignedRankAsymptotic(d)
d=round(d(:),10); d=d(isfinite(d)&d~=0);
n=numel(d);
if n==0, W=NaN; p=NaN; return; end
r=averageRanks(abs(d));
wp=sum(r(d>0)); wn=sum(r(d<0)); W=min(wp,wn);
mu=n*(n+1)/4;
sigma=sqrt(sum(r.^2)/4);
if sigma==0, p=1; else, z=(wp-mu)/sigma; p=erfc(abs(z)/sqrt(2)); end
end

function adj=holmAdjust(p)
p=p(:); adj=nan(size(p)); valid=find(isfinite(p));
if isempty(valid), return; end
[ps,ord]=sort(p(valid)); m=numel(ps);
a=cummax(min(1,(m-(0:m-1)').*ps));
adj(valid(ord))=a;
end

%% Adaptive knot placement and Gaussian-process regression
function [T17,TA8a,TA8b,adaptiveM,gpDiagnostics]=makeAdaptiveGPComparison(R)
fitRows=cell(0,9); heldRows=cell(0,9); summaryRows=cell(0,8);
gpDiagRows=cell(0,7);
adaptiveM=struct();
for s=1:numel(R)
    y=R(s).y(:); n=numel(y);
    starts=(1:24:n-24)';
    fixedFit=nan(n,1); adaptFit=nan(n,1); gpFit=nan(n,1);
    heldY=[]; fixedHeld=[]; adaptHeld=[]; gpHeld=[];
    blockCount=0;
    gpTotal=0; gpConverged=0; gpIterSum=0; gpMaxIter=0; gpMaxGrad=0;
    for q=1:numel(starts)
        a=starts(q); z=y(a:a+24);
        if any(~isfinite(z)), continue; end
        blockCount=blockCount+1;
        [pf,~]=piecewiseCubicBlock(z,[0 8 16 24],-1);
        [pa,~,~]=adaptiveCubicBlock(z,-1);
        [pg,info]=gpPredictMATLAB((0:24)',z,(0:24)');
        gpTotal=gpTotal+1;
        gpConverged=gpConverged+double(info.Converged);
        gpIterSum=gpIterSum+info.Iterations;
        gpMaxIter=max(gpMaxIter,info.BestStartIterations);
        gpMaxGrad=max(gpMaxGrad,info.ProjectedGradientInfNorm);
        ii=a:a+24;
        fixedFit(ii)=pf; adaptFit(ii)=pa; gpFit(ii)=pg;
        for k=[1:7,9:15,17:23]
            [pfh,~]=piecewiseCubicBlock(z,[0 8 16 24],k);
            [pah,~,~]=adaptiveCubicBlock(z,k);
            [pgh,info]=gpPredictMATLAB((0:24)',z,k,k);
            gpTotal=gpTotal+1;
            gpConverged=gpConverged+double(info.Converged);
            gpIterSum=gpIterSum+info.Iterations;
            gpMaxIter=max(gpMaxIter,info.BestStartIterations);
            gpMaxGrad=max(gpMaxGrad,info.ProjectedGradientInfNorm);
            heldY(end+1,1)=z(k+1); %#ok<AGROW>
            fixedHeld(end+1,1)=pfh(k+1); %#ok<AGROW>
            adaptHeld(end+1,1)=pah(k+1); %#ok<AGROW>
            gpHeld(end+1,1)=pgh; %#ok<AGROW>
        end
    end
    meth={'Fixed','Adaptive','GP'};
    fitPred={fixedFit,adaptFit,gpFit};
    heldPred={fixedHeld,adaptHeld,gpHeld};
    fitM=zeros(3,5); heldM=zeros(3,5);
    for j=1:3
        fitM(j,:)=metricVector(y,fitPred{j});
        heldM(j,:)=metricVector(heldY,heldPred{j});
        fitRows(end+1,:)={R(s).name,meth{j},'F',fitM(j,1),fitM(j,2),fitM(j,3),fitM(j,4),fitM(j,5),blockCount}; %#ok<AGROW>
        heldRows(end+1,:)={R(s).name,meth{j},'H',heldM(j,1),heldM(j,2),heldM(j,3),heldM(j,4),heldM(j,5),blockCount}; %#ok<AGROW>
    end
    summaryRows(end+1,:)={R(s).name,blockCount,fitM(1,2),fitM(2,2),fitM(3,2),heldM(1,2),heldM(2,2),heldM(3,2)}; %#ok<AGROW>
    if gpTotal>0, meanIter=gpIterSum/gpTotal; else, meanIter=NaN; end
    gpDiagRows(end+1,:)={R(s).name,gpTotal,gpConverged,gpTotal-gpConverged,meanIter,gpMaxIter,gpMaxGrad}; %#ok<AGROW>
    fprintf('  Set %s: %d complete blocks; %d/%d GP fits met the projected-gradient tolerance.\n', ...
        R(s).name,blockCount,gpConverged,gpTotal);
    if strcmp(R(s).name,'M')
        adaptiveM=struct('starts',starts,'fixedFit',fixedFit,'adaptiveFit',adaptFit, ...
            'gpFit',gpFit,'blocks',blockCount,'y',y);
    end
end
Tall=cell2table(fitRows,'VariableNames',{'Set','Method','Evaluation','N','RMSE','MAE','MAPE_percent','R2','Blocks'});
Theld=cell2table(heldRows,'VariableNames',{'Set','Method','Evaluation','N','RMSE','MAE','MAPE_percent','R2','Blocks'});
TA8a=[Tall(strcmp(string(Tall.Set),'N')|strcmp(string(Tall.Set),'A')|strcmp(string(Tall.Set),'M'),:); ...
      Theld(strcmp(string(Theld.Set),'N')|strcmp(string(Theld.Set),'A')|strcmp(string(Theld.Set),'M'),:)];
TA8b=[Tall(strcmp(string(Tall.Set),'1')|strcmp(string(Tall.Set),'2')|strcmp(string(Tall.Set),'3'),:); ...
      Theld(strcmp(string(Theld.Set),'1')|strcmp(string(Theld.Set),'2')|strcmp(string(Theld.Set),'3'),:)];
T17=cell2table(summaryRows,'VariableNames',{'Set','Blocks','FixedFitRMSE','AdaptiveFitRMSE','GPFitRMSE','FixedHeldRMSE','AdaptiveHeldRMSE','GPHeldRMSE'});
gpDiagnostics=cell2table(gpDiagRows,'VariableNames',{'Set','TotalGPFits','ConvergedFits','FiniteFallbackFits','MeanOptimizerIterations','MaximumIterationsPerStart','MaximumProjectedGradientInfNorm'});
end

function [pred,sse]=piecewiseCubicBlock(z,knots,held)
z=z(:); pred=nan(25,1); sse=0;
for j=1:3
    a=knots(j); b=knots(j+1); xx=(a:b)';
    localIdx=xx+1;
    train=true(size(xx));
    if held>=0, train=xx~=held; end
    if ~train(1)||~train(end), sse=Inf; return; end
    p=fitBezier(xx(train)-a,z(localIdx(train)),3,xx-a,b-a);
    pred(localIdx)=p;
    sse=sse+sum((z(localIdx(train))-p(train)).^2);
end
end

function [pred,knots,best]=adaptiveCubicBlock(z,held)
best=Inf; pred=nan(25,1); knots=[0 8 16 24];
for a=4:16
    for b=a+4:min(a+16,20)
        if (24-b)<4 || (24-b)>16 || a==held || b==held, continue; end
        kk=[0 a b 24];
        [p,sse]=piecewiseCubicBlock(z,kk,held);
        if sse<best-1e-12
            best=sse; pred=p; knots=kk;
        end
    end
end
end

function [pred,info]=gpPredictMATLAB(xTrain,yTrain,xQuery,held)
% Squared-exponential GP with empirical constant mean, population scaling,
% independent Gaussian observation noise, and bounded analytic-gradient BFGS.
if nargin<4, held=-1; end
xTrain=xTrain(:); yTrain=yTrain(:); xQuery=xQuery(:);
if held>=0
    keep=xTrain~=held; xTrain=xTrain(keep); yTrain=yTrain(keep);
end
if numel(xTrain)<3 || numel(xTrain)~=numel(yTrain) || any(~isfinite(yTrain))
    error('GP training data are invalid or contain fewer than three observations.');
end
mu=mean(yTrain);
sc=max(std(yTrain,1),1);
z=(yTrain-mu)/sc;
logLo=log([.1;.5;.001]);
logHi=log([10;24;1]);
D2=(xTrain-xTrain').^2;
I=eye(numel(xTrain));
objective=@(theta)gpNLLGradient(theta,D2,I,z);

% Deterministic multi-start search reduces sensitivity to local likelihood minima.
% The original [1,4,0.1] start is retained; additional starts probe shorter and
% longer correlation scales. The lowest finite bounded objective is retained.
startSet=[log([1;4;.1]), log([1;1.5;.2]), log([2;8;.2]), log([.2;.5;.001])];
bestTheta=[]; bestF=Inf; bestExit=-1; bestIter=0; bestGrad=Inf;
totalIterations=0;
for q=1:size(startSet,2)
    [tq,fq,eq,iq,gq]=gpBoundedBFGS(objective,startSet(:,q),logLo,logHi);
    totalIterations=totalIterations+iq;
    if isfinite(fq) && fq<1e90 && fq<bestF
        bestTheta=tq; bestF=fq; bestExit=eq; bestIter=iq; bestGrad=gq;
    end
end
if ~isempty(bestTheta) && (exp(bestTheta(2))>3 || exp(bestTheta(3))>.25 || bestExit~=1)
    extraStarts=[log([.5;2;.05]),log([5;1;.2])];
    for q=1:size(extraStarts,2)
        [tq,fq,eq,iq,gq]=gpBoundedBFGS(objective,extraStarts(:,q),logLo,logHi);
        totalIterations=totalIterations+iq;
        if isfinite(fq) && fq<1e90 && fq<bestF
            bestTheta=tq; bestF=fq; bestExit=eq; bestIter=iq; bestGrad=gq;
        end
    end
end
if isempty(bestTheta) || ~isfinite(bestF) || bestF>=1e90
    error('Gaussian-process optimization failed: no finite bounded hyperparameter solution was obtained.');
end
par=exp(bestTheta); sf=par(1); ell=par(2); sn=par(3);
D=D2;
K=sf^2*exp(-0.5*D/ell^2)+(sn^2+1e-8)*I;
[L,p]=chol(K,'lower');
if p~=0
    error('Gaussian-process covariance matrix is not positive definite at the selected hyperparameters.');
end
alpha=L'\(L\z);
cross=sf^2*exp(-0.5*((xQuery-xTrain')/ell).^2);
pred=mu+sc*(cross*alpha);
info=struct('Converged',bestExit==1,'ExitFlag',bestExit,'Iterations',totalIterations, ...
    'BestStartIterations',bestIter,'ProjectedGradientInfNorm',bestGrad, ...
    'NegativeLogMarginalLikelihood',bestF, ...
    'Optimizer','MATLAB bounded projected BFGS with analytic gradient and deterministic multi-start');
end

function [f,g]=gpNLLGradient(theta,D,I,y)
% Exact negative-log-marginal-likelihood gradient with respect to log(sf,ell,sn).
% The squared-distance matrix and identity matrix are precomputed once per fit.
theta=theta(:); y=y(:);
sf=exp(theta(1)); ell=exp(theta(2)); sn=exp(theta(3));
R=exp(-0.5*D/ell^2);
K=sf^2*R+(sn^2+1e-8)*I;
[L,p]=chol(K,'lower');
if p~=0
    f=1e100; g=zeros(3,1); return;
end
alpha=L'\(L\y);
f=.5*(y'*alpha)+sum(log(diag(L)))+.5*numel(y)*log(2*pi);
if nargout>1
    Kinv=L'\(L\I);
    A=Kinv-alpha*alpha';
    dKsf=2*sf^2*R;
    dKell=sf^2*R.*(D/ell^2);
    dKsn=2*sn^2*I;
    g=.5*[sum(sum(A.*dKsf));sum(sum(A.*dKell));sum(sum(A.*dKsn))];
end
if ~isfinite(f) || f>=1e90
    f=1e100; g=zeros(3,1);
end
end


function [x,f,exitflag,iter,gradNorm]=gpBoundedBFGS(fun,x0,lb,ub)
% Small-dimensional bound-constrained BFGS with projected gradients and
% Armijo backtracking. It requires no Optimization Toolbox.
x=min(max(x0(:),lb(:)),ub(:));
[f,g]=fun(x);
H=eye(numel(x));
exitflag=0; iter=0; gradNorm=Inf;
if ~isfinite(f) || f>=1e90
    exitflag=-1; return;
end
maxIter=200; gTol=1e-6;
for iter=1:maxIter
    pg=g;
    atLo=x<=lb+1e-10; atHi=x>=ub-1e-10;
    pg(atLo & g>0)=0;
    pg(atHi & g<0)=0;
    gradNorm=norm(pg,inf);
    if gradNorm<gTol
        exitflag=1; break;
    end
    d=-H*pg;
    d(atLo & d<0)=0;
    d(atHi & d>0)=0;
    if g'*d>=-1e-12
        H=eye(numel(x)); d=-pg;
        d(atLo & d<0)=0;
        d(atHi & d>0)=0;
    end
    accepted=false; alpha=1;
    for ls=1:40
        xn=min(max(x+alpha*d,lb),ub);
        step=xn-x;
        if norm(step,inf)<1e-12
            alpha=alpha/2; continue;
        end
        [fn,gn]=fun(xn);
        if isfinite(fn) && fn<1e90 && fn<=f+1e-4*(g'*step)+1e-12
            accepted=true; break;
        end
        alpha=alpha/2;
    end
    if ~accepted
        d=-pg; alpha=.1;
        for ls=1:50
            xn=min(max(x+alpha*d,lb),ub);
            step=xn-x;
            if norm(step,inf)<1e-12
                alpha=alpha/2; continue;
            end
            [fn,gn]=fun(xn);
            if isfinite(fn) && fn<1e90 && fn<f
                accepted=true; break;
            end
            alpha=alpha/2;
        end
    end
    if ~accepted
        exitflag=2; break;
    end
    yk=gn-g; ys=yk'*step;
    if ys>1e-12*norm(yk)*norm(step)
        rho=1/ys; V=eye(numel(x))-rho*step*yk';
        H=V*H*V'+rho*(step*step');
    else
        H=eye(numel(x));
    end
    oldf=f; x=xn; f=fn; g=gn;
    pg=g;
    atLo=x<=lb+1e-10; atHi=x>=ub-1e-10;
    pg(atLo & g>0)=0; pg(atHi & g<0)=0;
    gradNorm=norm(pg,inf);
    if gradNorm<gTol
        exitflag=1; break;
    end
    if abs(oldf-f)<=1e-10*(1+abs(oldf)) && gradNorm<1e-4
        exitflag=2; break;
    end
end
if exitflag==0 && isfinite(f) && f<1e90
    exitflag=2;
end
end

%% External 3-hour Kp association
function [T19,TA11]=makeKpTables(R,kpPath,nRep,seed)
K=readtable(kpPath,'TextType','string','VariableNamingRule','preserve');
v=string(K.Properties.VariableNames);
it=find(strcmpi(v,'start_utc'),1); ik=find(strcmpi(v,'kp'),1);
if isempty(it)||isempty(ik), error('Kp file must contain start_utc and kp columns.'); end
rawTime=K{:,it};
rawKp=K{:,ik};
if isnumeric(rawKp), kp=double(rawKp); else, kp=str2double(string(rawKp)); end
if isdatetime(rawTime)
    kt=rawTime(:); kt.TimeZone='UTC';
    ok=~isnat(kt) & isfinite(kp); kt=kt(ok); kp=kp(ok);
else
    ts=strtrim(string(rawTime));
    ok=~ismissing(ts) & strlength(ts)>0 & isfinite(kp); ts=ts(ok); kp=kp(ok);
    try
        kt=datetime(ts,'InputFormat',"yyyy-MM-dd'T'HH:mm:ss'Z'",'TimeZone','UTC');
    catch
        kt=datetime(ts,'TimeZone','UTC');
    end
end
if isempty(kt), error('The selected Kp file contains no valid records.'); end
[kt,ord]=sort(kt); kp=kp(ord);
if any(kp<0|kp>9) || any(diff(kt)<hours(3))
    error('Kp values or interval ordering are invalid. Check the GFZ 3-hour archive.');
end
if any(minute(kt)~=0 | second(kt)~=0 | mod(hour(kt),3)~=0)
    error('Kp timestamps must mark exact 3-hour interval starts (00, 03, 06, ..., 21 UTC).');
end
C19=cell(0,8); CA11=cell(0,8);
stream=RandStream('mt19937ar','Seed',seed);
for s=1:numel(R)
    D=R(s); starts=D.LAI.starts; L=D.LAI.values;
    n=numel(starts); V=nan(n,2); ordBlock=(starts-1)/8;
    for j=1:n
        if isnat(D.utc(starts(j))), continue; end
        t0=D.utc(starts(j)); t1=t0+hours(8);
        ix=(kt<t1) & (kt+hours(3)>t0);
        if any(ix)
            a=kt(ix); b=a+hours(3);
            a(a<t0)=t0;
            b(b>t1)=t1;
            ov=hours(b-a);
            if abs(sum(ov)-8)<1e-8
                V(j,1)=sum(ov.*kp(ix))/8;
                V(j,2)=max(kp(ix));
            end
        end
    end
    valid=isfinite(L)&all(isfinite(V),2);
    L=L(valid); V=V(valid,:); ordBlock=ordBlock(valid);
    rho=zeros(1,2); ci24=nan(2,2); ci72=nan(2,2);
    for metric=1:2
        rho(metric)=spearmanRank(L,V(:,metric));
        ci24(metric,:)=kpBootstrap(L,V(:,metric),ordBlock,3,nRep,stream);
        ci72(metric,:)=kpBootstrap(L,V(:,metric),ordBlock,9,nRep,stream);
    end
    C19(end+1,:)={D.name,numel(L),rho(1),ci24(1,1),ci24(1,2),rho(2),ci24(2,1),ci24(2,2)}; %#ok<AGROW>
    CA11(end+1,:)={D.name,numel(L),rho(1),ci72(1,1),ci72(1,2),rho(2),ci72(2,1),ci72(2,2)}; %#ok<AGROW>
end
T19=cell2table(C19,'VariableNames',{'Set','PairedBlocks','WeightedMeanKp_Spearman','WeightedMeanKp_Lower95_24h','WeightedMeanKp_Upper95_24h', ...
    'MaximumKp_Spearman','MaximumKp_Lower95_24h','MaximumKp_Upper95_24h'});
TA11=cell2table(CA11,'VariableNames',{'Set','PairedBlocks','WeightedMeanKp_Spearman','WeightedMeanKp_Lower95_72h','WeightedMeanKp_Upper95_72h', ...
    'MaximumKp_Spearman','MaximumKp_Lower95_72h','MaximumKp_Upper95_72h'});
end

function ci=kpBootstrap(L,V,blockOrdinal,blockLength,nRep,stream)
n=numel(L);
candidate=[];
for a=1:n-blockLength+1
    if all(diff(blockOrdinal(a:a+blockLength-1))==1)
        candidate(end+1,1)=a; %#ok<AGROW>
    end
end
if isempty(candidate), ci=[NaN NaN]; return; end
rho=zeros(nRep,1);
for b=1:nRep
    nRun=ceil(n/blockLength);
    picked=candidate(randi(stream,numel(candidate),nRun,1));
    ids=reshape((picked+(0:blockLength-1))',[],1);
    ids=ids(1:n);
    rho(b)=spearmanRank(L(ids),V(ids));
end
ci=quantileLinear(rho,[.025 .975]);
end

%% MATLAB-host runtime measurements
function T=makeRuntimeTable(R,h)
methods={'Bezier 2','Bezier 3','Bezier 4','Bezier 5','Bezier 6', ...
    'Linear','Cubic spline','Hermite','Lagrange','C1 cubic'};
nW=numel(R.starts); C=cell(0,8);
for m=1:numel(methods)
    for k=1:3, runTimedMethod(R.y,h,m); end
    times=zeros(21,1);
    for k=1:21
        t=tic; runTimedMethod(R.y,h,m); times(k)=toc(t)*1000;
    end
    q=quantileLinear(times,[.25 .50 .75]);
    if m<=5
        d=m+1; pred=fitAll(R.y,h,d,false); rm=metricVector(R.y,pred(:,1)); 
        nStored=nW*d+2; nParam=nW*(d-1);
    elseif m<=9
        cidx=m-5; pred=fitClassicalSingle(R.y,h,cidx); rm=metricVector(R.y,pred);
        nStored=3*nW+2; nParam=2*nW;
    else
        st=validWindowStarts(R.y,h); pred=continuousCubic(R.y,st,h); rm=metricVector(R.y,pred);
        nStored=2*(nW+1)+1; nParam=nW+1;
    end
    C(end+1,:)={methods{m},rm(2),nStored,nStored*8/1024, ...
        numel(R.y)/nStored,q(2),q(1),q(3)}; %#ok<AGROW>
end
T=cell2table(C,'VariableNames',{'Method','RMSE_km_s','StoredScalars','StorageKiB','RawToStoredRatio','TimeMedian_ms','TimeQ25_ms','TimeQ75_ms'});
end

function runTimedMethod(y,h,methodIndex)
if methodIndex<=5
    [P,~]=fitAll(y,h,methodIndex+1,false);
    metricVector(y,P(:,1));
elseif methodIndex<=9
    p=fitClassicalSingle(y,h,methodIndex-5);
    metricVector(y,p);
else
    st=validWindowStarts(y,h);
    p=continuousCubic(y,st,h);
    metricVector(y,p);
end
end

function p=fitClassicalSingle(y,h,methodIndex)
y=y(:); p=nan(size(y)); starts=validWindowStarts(y,h); x=(0:h)';
for q=1:numel(starts)
    a=starts(q); z=y(a:a+h);
    p(a:a+h)=classicalFitOne(x,z,x,h,methodIndex);
end
end

%% Figure generation
function indexTable=createManuscriptFigures(R,figDir,adaptiveM,runGP)
rows=cell(0,4);
blue=[0.1216 0.4667 0.7059];
orange=[1.0000 0.4980 0.0549];
green=[0.1725 0.6275 0.1725];

% Figures 1-3: separate Set M quadratic, cubic and quartic full-series plots.
for d=2:4
    f=newFigure(10,4.06);
    x=(0:numel(R(3).y)-1)';
    plot(x,R(3).y,'Color',blue,'LineWidth',0.65); hold on;
    plot(x,R(3).P(:,d-1),'Color',orange,'LineWidth',0.75);
    xlim([0 numel(x)-1]); xticks(0:500:2500); ylim([250 1160]);
    xlabel('Hour'); ylabel('Solar-wind velocity (km/s)');
    title(sprintf('Set M — degree %d, 8-hour segmentation',d));
    legend('Observed Set M',sprintf('Bézier estimate (d=%d)',d),'Location','northeast');
    grid on; set(gca,'FontName','Arial','FontSize',10,'LineWidth',0.8);
    id=sprintf('Figure_%02d',d-1);
    saveFigure(f,fullfile(figDir,id));
    rows(end+1,:)={id,sprintf('Set M degree %d full-series Bézier representation',d),[id '.png'],[id '.pdf']}; %#ok<AGROW>
end

% Figures 4-6: four-panel classical comparisons for Sets N, A and M.
for s=1:3
    f=newFigure(10,7);
    plotClassicalPanels(R(s),f);
    id=sprintf('Figure_%02d',s+3);
    saveFigure(f,fullfile(figDir,id));
    rows(end+1,:)={id,['Classical methods, Set ' R(s).name],[id '.png'],[id '.pdf']}; %#ok<AGROW>
end

% Figures 7-8: Set M 12- and 24-hour Bézier representations.
for k=1:2
    hh=[12 24]; win=hh(k);
    [P,~]=fitAll(R(3).y,win,2:4,false);
    f=newFigure(10,11.1);
    x=(0:numel(R(3).y)-1)';
    for j=1:3
        subplot(3,1,j);
        plot(x,R(3).y,'Color',blue,'LineWidth',0.55); hold on;
        plot(x,P(:,j),'Color',orange,'LineWidth',0.7);
        xlim([0 numel(x)-1]); xticks(0:500:2500); ylim([250 1200]);
        ylabel('Solar-wind speed (km/s)');
        xlabel('Hour');
        title(sprintf('Set M — degree %d, %d-hour segmentation',j+1,win));
        legend('Observed Set M',sprintf('Bézier estimate (d=%d)',j+1),'Location','northeast');
        grid on; set(gca,'FontName','Arial','FontSize',9,'LineWidth',0.8);
    end
    id=sprintf('Figure_%02d',k+6);
    saveFigure(f,fullfile(figDir,id));
    rows(end+1,:)={id,sprintf('Set M %d-hour Bézier sensitivity',win),[id '.png'],[id '.pdf']}; %#ok<AGROW>
end

% Figures 9-11: three separate degree panels for each 2017 period.
for s=4:6
    f=newFigure(10,8.33);
    x=elapsedHours(R(s));
    for j=1:3
        subplot(3,1,j);
        plot(x,R(s).y,'Color',blue,'LineWidth',0.55); hold on;
        plot(x,R(s).P(:,j),'Color',orange,'LineWidth',0.7);
        xlim([0 x(end)]);
        ylabel('Speed (km/s)');
        xlabel(timeAxisLabel(R(s)));
        title(sprintf('Set %s — degree %d, 8-hour segmentation',R(s).name,j+1));
        legend('Observed',sprintf('Bézier degree %d',j+1),'Location','northeast');
        grid on; set(gca,'FontName','Arial','FontSize',9,'LineWidth',0.8);
    end
    id=sprintf('Figure_%02d',s+5);
    saveFigure(f,fullfile(figDir,id));
    rows(end+1,:)={id,['Full-series Bézier representation, Set ' R(s).name],[id '.png'],[id '.pdf']}; %#ok<AGROW>
end

% Figure 12: high-variability interpolation windows and withheld residuals.
f=newFigure(10,9.44);
for j=1:3
    s=j+3; a=highestStdWindow(R(s),8);
    z=R(s).y(a:a+8);
    xAll=elapsedHours(R(s));
    xw=xAll(a:a+8);
    xx=(0:8)'; xe=linspace(0,8,321)';
    pp=classicalFit(xx,z,xe,8);
    xeAbs=xw(1)+xe;
    subplot(3,2,2*j-1);
    plot(xw,z,'ko-','LineWidth',0.8,'MarkerFaceColor','k','DisplayName','Observed'); hold on;
    plot(xeAbs,pp(:,1),'--','Color',blue,'LineWidth',1.1,'DisplayName','Linear');
    plot(xeAbs,pp(:,3),':','Color',green,'LineWidth',1.4,'DisplayName','Hermite');
    plot(xeAbs,pp(:,4),'-.','Color',orange,'LineWidth',1.1,'DisplayName','Lagrange');
    xlim([xw(1) xw(end)]);
    title(sprintf('Set %s · highest-variability window',R(s).name));
    xlabel('Elapsed hours'); ylabel('Speed (km/s)');
    legend('Location','northwest'); grid on;

    subplot(3,2,2*j);
    e3=R(s).HY-R(s).H(:,2);
    e4=R(s).HY-R(s).H(:,3);
    xHeld=xAll(R(s).HI);
    plot(xHeld,e3,'.','Color',blue,'MarkerSize',3,'DisplayName','Bézier 3'); hold on;
    plot(xHeld,e4,'.','Color',orange,'MarkerSize',3,'DisplayName','Bézier 4');
    xlim([0 xAll(end)]);
    title(sprintf('Set %s · withheld-observation residuals',R(s).name));
    xlabel('Elapsed hours'); ylabel('Observed − reconstructed (km/s)');
    legend('Location','best'); grid on;
end
id='Figure_12'; saveFigure(f,fullfile(figDir,id));
rows(end+1,:)={id,'Local interpolation and withheld-observation residuals for Sets 1-3',[id '.png'],[id '.pdf']};

% Figures 13-15: four-panel classical comparisons for Sets 1-3.
for s=4:6
    f=newFigure(10,6.5);
    plotClassicalPanels(R(s),f);
    id=sprintf('Figure_%02d',s+9);
    saveFigure(f,fullfile(figDir,id));
    rows(end+1,:)={id,['Classical methods, Set ' R(s).name],[id '.png'],[id '.pdf']}; %#ok<AGROW>
end

% Figures A1-A3: enlarged lower- and higher-variability windows for Sets 1-3.
for s=4:6
    f=makeZoomFigure(R(s),true);
    id=sprintf('Figure_A%d',s-3);
    saveFigure(f,fullfile(figDir,id));
    rows(end+1,:)={id,['Enlarged Bézier windows, Set ' R(s).name],[id '.png'],[id '.pdf']}; %#ok<AGROW>
end

% Figures A4-A7: residuals, density, normal Q-Q and signed derivative jumps.
for s=[3 4 5 6]
    f=makeResidualDiagnosticFigure(R(s));
    id=sprintf('Figure_A%d',s+1);
    saveFigure(f,fullfile(figDir,id));
    rows(end+1,:)={id,['Residual and derivative diagnostics, Set ' R(s).name],[id '.png'],[id '.pdf']}; %#ok<AGROW>
end

% Figures A8-A10: enlarged original-series windows for Sets N, A and M.
for s=1:3
    f=makeZoomFigure(R(s),false);
    id=sprintf('Figure_A%d',s+7);
    saveFigure(f,fullfile(figDir,id));
    rows(end+1,:)={id,['Enlarged Bézier windows, Set ' R(s).name],[id '.png'],[id '.pdf']}; %#ok<AGROW>
end

% Figure A11: descriptive Bland-Altman views for quartic in-sample fits.
f=newFigure(10,6.48);
for j=1:4
    s=j+2; ok=isfinite(R(s).y)&isfinite(R(s).P(:,3));
    avg=(R(s).y(ok)+R(s).P(ok,3))/2;
    residual=R(s).P(ok,3)-R(s).y(ok);
    bias=mean(residual); sd=std(residual,0);
    subplot(2,2,j);
    scatter(avg,residual,8,blue,'filled','MarkerFaceAlpha',0.30,'MarkerEdgeAlpha',0.20); hold on;
    yline(bias,'k-','LineWidth',1.1);
    yline(bias+1.96*sd,'--r','LineWidth',1.1);
    yline(bias-1.96*sd,'--r','LineWidth',1.1);
    xlabel('Mean of observation and fitted speed (km/s)');
    ylabel('Fitted − observed (km/s)');
    title(['Set ' R(s).name]); grid on;
    set(gca,'FontName','Arial','FontSize',9,'LineWidth',0.8);
end
sgtitle('Descriptive Bland–Altman views: quartic in-sample representation');
id='Figure_A11'; saveFigure(f,fullfile(figDir,id));
rows(end+1,:)={id,'Descriptive Bland-Altman views for quartic fits',[id '.png'],[id '.pdf']};

% Figure A12: fixed and adaptively placed cubic segments in the highest-
% variability complete 24-hour Set M block.
if isempty(adaptiveM) || ~isfield(adaptiveM,'y')
    adaptiveM=buildAdaptiveFigureData(R(3));
end
f=makeAdaptiveIllustration(R(3),adaptiveM);
id='Figure_A12'; saveFigure(f,fullfile(figDir,id));
rows(end+1,:)={id,'Fixed and adaptive cubic segments in the Set M 24-hour block',[id '.png'],[id '.pdf']};

indexTable=cell2table(rows,'VariableNames',{'FigureID','Description','PNG_File','PDF_File'});
end

function plotClassicalPanels(R,f)
figure(f);
x=elapsedHours(R);
names={'Linear','Cubic spline','Hermite','Lagrange'};
legends={'Linear','Spline','Hermite','Lagrange'};
for j=1:4
    subplot(2,2,j);
    plot(x,R.y,'Color',[0 0 1],'LineWidth',0.55); hold on;
    plot(x,R.P(:,5+j),'--','Color',[1 0 0],'LineWidth',0.65);
    title(sprintf('Set %s · %s',R.name,names{j}));
    xlabel(timeAxisLabel(R));
    ylabel('Speed (km/s)');
    legend('Observed',legends{j},'Location','best');
    xlim([0 x(end)]);
    grid on; set(gca,'FontName','Arial','FontSize',9,'LineWidth',0.8);
end
end

function f=makeZoomFigure(R,usePeriodLabel)
f=newFigure(10,6);
low=lowerQuartileStdWindow(R,8);
high=highestStdWindow(R,8);
xAll=elapsedHours(R);
for j=1:2
    if j==1
        a=low; ttl='Lower-variability window';
    else
        a=high;
        if usePeriodLabel, ttl='Highest-variability complete window'; else, ttl='Highest-variability window'; end
    end
    z=R.y(a:a+8);
    xw=xAll(a:a+8);
    xx=(0:8)'; xe=linspace(0,8,241)';
    subplot(2,1,j);
    if usePeriodLabel
        plot(xw,z,'ko-','LineWidth',0.8,'MarkerFaceColor','k','DisplayName','Observed'); hold on;
    else
        plot(xw,z,'ko','LineWidth',0.8,'MarkerFaceColor','k','DisplayName','Observed'); hold on;
    end
    curveColors={[0.1216 0.4667 0.7059],[1.0000 0.4980 0.0549],[0.1725 0.6275 0.1725]};
    for d=2:4
        pp=fitBezier(xx,z,d,xe,8);
        plot(xw(1)+xe,pp,'Color',curveColors{d-1},'LineWidth',1.05,'DisplayName',sprintf('Degree %d',d));
    end
    if usePeriodLabel
        title(sprintf('Set %s — %s',R.name,ttl));
        ylabel('Speed (km/s)');
        xlabel(timeAxisLabel(R));
    else
        title(ttl);
        ylabel('Solar wind speed (km/s)');
        if any(strcmp(R.name,{'N','A'}))
            xlabel('Observation index (zero-based)');
        else
            xlabel('Elapsed hour');
        end
    end
    xlim([xw(1) xw(end)]);
    xticks(xw);
    legend('Location','best'); grid on;
    set(gca,'FontName','Arial','FontSize',9,'LineWidth',0.8);
end
if ~usePeriodLabel
    sgtitle(sprintf('Set %s: enlarged original-series representations',R.name));
end
end


function f=makeResidualDiagnosticFigure(R)
f=newFigure(10,6.3);
x=elapsedHours(R);
cols=[0.1216 0.4667 0.7059;1.0000 0.4980 0.0549];
for j=1:2
    degree=j+2;
    col=cols(j,:);
    residual=R.y-R.P(:,degree);
    valid=isfinite(residual);
    rr=residual(valid);
    subplot(2,2,1); hold on;
    plot(x(valid),rr,'Color',col,'LineWidth',0.5,'DisplayName',sprintf('Degree %d',degree));
    subplot(2,2,2); hold on;
    histogram(rr,40,'Normalization','pdf','EdgeColor',col,'FaceColor',col, ...
        'FaceAlpha',0.28,'DisplayName',sprintf('Degree %d',degree));
    subplot(2,2,3); hold on;
    n=numel(rr); p=((1:n)'-.5)/n; tq=sqrt(2)*erfinv(2*p-1);
    plot(tq,sort(rr),'Color',col,'LineWidth',0.65,'DisplayName',sprintf('Degree %d',degree));
    J=knotJumps(R.starts,R.controls{degree-1},degree,8);
    subplot(2,2,4); hold on;
    if ~isempty(J)
        plot(J.KnotIndex,J.SignedDerivativeJump,'Color',col,'LineWidth',0.65, ...
            'DisplayName',sprintf('Degree %d',degree));
    end
end
subplot(2,2,1);
title('Residual sequence'); xlabel('Elapsed hour'); ylabel('Observed − fitted speed (km/s)');
legend('Location','best'); grid on;
subplot(2,2,2);
title('Residual distribution'); xlabel('Residual (km/s)'); ylabel('Density');
legend('Location','best'); grid on;
subplot(2,2,3);
title('Normal Q-Q comparison'); xlabel('Standard-normal quantile'); ylabel('Ordered residual (km/s)');
legend('Location','best'); grid on;
subplot(2,2,4);
title('Signed derivative jumps at shared knots'); xlabel('Join: elapsed hour');
ylabel('Right − left slope (km/s per hour)'); legend('Location','best'); grid on;
sgtitle(sprintf('Set %s: in-sample residuals and derivative jumps',R.name));
end

function x=elapsedHours(R)
if isempty(R.utc) || all(isnat(R.utc))
    x=(0:numel(R.y)-1)';
else
    x=hours(R.utc(:)-R.utc(1));
end
end

function label=timeAxisLabel(R)
switch string(R.name)
    case {"N","A"}
        label='Observation index (zero-based)';
    case "M"
        label='Hours since 2026-01-01 00:00 UT';
    case "1"
        label='Hours since 2017-01-01 00:00 UT';
    case "2"
        label='Hours since 2017-05-01 00:00 UT';
    case "3"
        label='Hours since 2017-09-01 00:00 UT';
    otherwise
        label='Elapsed hours';
end
end


function a=lowerQuartileStdWindow(R,h)
starts=R.starts; v=nan(numel(starts),1);
for j=1:numel(starts), z=R.y(starts(j):starts(j)+h); v(j)=std(z,0); end
[~,ord]=sort(v,'ascend'); a=starts(ord(max(1,ceil(numel(ord)/4))));
end

function a=highestStdWindow(R,h)
starts=(1:h:numel(R.y)-h)';
v=nan(numel(starts),1); keep=false(numel(starts),1);
for j=1:numel(starts)
    z=R.y(starts(j):starts(j)+h);
    if all(isfinite(z)), v(j)=std(z,0); keep(j)=true; end
end
starts=starts(keep); v=v(keep);
if isempty(starts), a=1; else, [~,k]=max(v); a=starts(k); end
end

function a=lowerQuartileStdWindowLAI(R,h)
starts=(1:h:numel(R.y)-h)';
v=nan(numel(starts),1); keep=false(numel(starts),1);
for j=1:numel(starts)
    z=R.y(starts(j):starts(j)+h);
    if all(isfinite(z)), v(j)=std(z,0); keep(j)=true; end
end
starts=starts(keep); v=v(keep);
[~,ord]=sort(v,'ascend'); a=starts(ord(max(1,ceil(numel(ord)/4))));
end

function f=makeAdaptiveIllustration(R,A)
starts=(1:24:numel(R.y)-24)';
stds=nan(size(starts)); valid=false(size(starts));
for j=1:numel(starts)
    z=R.y(starts(j):starts(j)+24);
    if all(isfinite(z)), stds(j)=std(z,0); valid(j)=true; end
end
starts=starts(valid); stds=stds(valid);
if isempty(starts), error('No complete 24-hour Set M block is available for Figure A12.'); end
[~,ix]=max(stds); a=starts(ix); z=R.y(a:a+24);
fixed=piecewiseCubicBlock(z,[0 8 16 24],-1);
[adapt,knots]=adaptiveCubicBlock(z,-1);
f=newFigure(10,3.7);
x=a-1+(0:24);
plot(x,z,'ko-','LineWidth',0.8,'MarkerFaceColor','k','DisplayName','Observed'); hold on;
plot(x,fixed,'Color',[0.1216 0.4667 0.7059],'LineWidth',1.6,'DisplayName','Fixed cubic');
plot(x,adapt,'Color',[1.0000 0.4980 0.0549],'LineWidth',1.6,'DisplayName','Adaptive cubic');
xline(a-1+knots(2),':','Color',[0.1725 0.6275 0.1725],'LineWidth',1.5,'HandleVisibility','off');
xline(a-1+knots(3),':','Color',[0.1725 0.6275 0.1725],'LineWidth',1.5,'HandleVisibility','off');
xlabel('Elapsed hour from 2026-01-01 00:00 UT');
ylabel('Solar wind speed (km/s)');
title('Set M: highest-variability complete 24-hour block');
legend('Location','northwest'); grid on;
set(gca,'FontName','Arial','FontSize',10,'LineWidth',0.8);
end


function A=buildAdaptiveFigureData(R)
A=struct('y',R.y);
end


function s=formatUTCDate(t)
months={'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'};
s=sprintf('%02d %s %04d',day(t),months{month(t)},year(t));
end

function name=degreeName(d)
switch d
    case 2, name='Quadratic';
    case 3, name='Cubic';
    case 4, name='Quartic';
    otherwise, name=sprintf('Degree %d',d);
end
end

function f=newFigure(w,h)
f=figure('Visible','off','Color','w','Units','inches', ...
    'Position',[1 1 w h],'PaperPositionMode','auto');
set(f,'DefaultAxesFontName','Arial','DefaultTextFontName','Arial', ...
    'DefaultAxesFontSize',10,'DefaultLineLineWidth',0.8);
end

function saveFigure(f,path)
set(f,'PaperPositionMode','auto');
try
    exportgraphics(f,[path '.png'],'Resolution',600);
catch
    print(f,[path '.png'],'-dpng','-r600');
end
try
    exportgraphics(f,[path '.pdf'],'ContentType','vector');
catch
    print(f,[path '.pdf'],'-dpdf','-painters');
end
close(f);
end

%% Workbook and run summary
function writeResultWorkbook(xlsxFile,spec)
for k=1:size(spec,1)
    sheet=spec{k,1}; T=spec{k,2};
    if isempty(T) || width(T)==0
        T=table("Not calculated in this run.",'VariableNames',{'Status'});
    end
    try
        writetable(T,xlsxFile,'Sheet',sheet);
    catch ME
        warning('Could not write sheet %s: %s',sheet,ME.message);
    end
end
% Table 20 is a manually curated literature comparison, not a numerical output.
note=table("Manual literature-context table; values are not generated by the MATLAB analysis.", ...
    'VariableNames',{'Status'});
writetable(note,xlsxFile,'Sheet','Table_20_Manual');
end

function writeRunSummary(D,R,outDir,h,laiLength,runGP,runResampling,kpPath,methodNames,kpBootstrapReplicates)
f=fopen(fullfile(outDir,'RUN_SUMMARY.txt'),'w');
if f<0, return; end
fprintf(f,'Segmented Bezier Representation of Solar Wind Speed and Local Activity Index\n');
fprintf(f,'Interactive Excel-input MATLAB reproducibility run\n');
fprintf(f,'MATLAB version: %s\nComputer: %s\nDate: %s\n\n',version,computer,datestr(now,31));
fprintf(f,'Baseline Bezier window: %d intervals (%d observations)\n',h,h+1);
fprintf(f,'LAI block: %d non-overlapping observations\n',laiLength);
fprintf(f,'Bezier degrees: 2 through 6\n');
fprintf(f,'Classical methods: Linear, cubic spline, PCHIP Hermite, Lagrange\n');
fprintf(f,'Adaptive/GP analysis executed: %d\n',runGP);
fprintf(f,'GP optimizer: bounded projected BFGS with analytic gradient and deterministic multi-start; bounds [0.1,0.5,0.001] to [10,24,1].\n');
fprintf(f,'Bootstrap/perturbation executed: %d\n',runResampling);
fprintf(f,'Random streams: mt19937ar seeds 4691220 (bootstrap), 4691221 (perturbation), 4691222 (Kp bootstrap)\n');
fprintf(f,'Kp input: %s\nKp bootstrap replicates: %d\n',kpPath,kpBootstrapReplicates);
fprintf(f,'\nExcel datasets:\n');
for s=1:numel(D)
    fprintf(f,'Set %s | n=%d | missing=%d | source=%s | worksheet=%s | column=%s\n', ...
        D(s).name,numel(D(s).y),sum(~isfinite(D(s).y)),char(D(s).sourceFile), ...
        char(string(D(s).sourceSheet)),char(string(D(s).sourceColumn)));
end
fprintf(f,'\nFigure outputs: Figure_01-Figure_15 and Figure_A1-Figure_A12.\n');
fprintf(f,'All figures are exported as 600-dpi PNG and vector PDF.\n');
fprintf(f,'A separate Calibration_Offset_Check sheet contains the analytical common-offset sensitivity.\n');
fprintf(f,'Table 20 is a manually curated literature-context table and is not generated by this program.\n');
fprintf(f,'Table A7 reports fitted-parameter counts and analytical storage estimates; it does not estimate peak process memory.\n');
fprintf(f,'Runtime values are measured on the current MATLAB host and should be updated in the manuscript after execution.\n');
fprintf(f,'The workflow is implemented in MATLAB and reads all speed and Kp input data from user-selected Excel workbooks.\n');
fclose(f);
end


%% Small utility functions
function q=safeQuantile(x,p)
x=x(isfinite(x));
if isempty(x), q=NaN; else, z=quantileLinear(x,p); q=z(1); end
end

function v=safeMax(x)
x=x(isfinite(x));
if isempty(x), v=NaN; else, v=max(x); end
end
