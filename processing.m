
rd = phased.RangeResponse(SampleRate=fs,RangeMethod="FFT",SweepSlope=sweepslope);

rangeCompressed = zeros(23,950);
for ii = 1:size(data,2)

    [resp, rnggrid] = rd(data(:,ii));
    rangeCompressed(:,ii) = resp(268:290);

end

yticks = (1:23);
ytickslabel = rnggrid(268:290);
figure;imagesc(abs(rangeCompressed))
set(gca, 'YTickLabel', ytickslabel, 'YTick', yticks)

rgc_dopp = fft(rangeCompressed,[],2);

% figure;imagesc(abs(rgc_dopp))

v = 1.4/3;
 physconst("LightSpeed") / fc;
L = 0.08;

rdc = rnggrid(268:290);
fdop = 0;
fRate = -(2*v^2/lambda)./rdc;                 % azimuth chirp rate
az_beamwidth = rdc * (lambda/L);       
tau_az = az_beamwidth/v;                      % azimuth pulse length
azRef = zeros(size(rgc_dopp),'like',rgc_dopp);

for rangeBin = 1:size(rgc_dopp,1)
    azRef(rangeBin,:) = getAzimuthChirp(fdop,fRate(rangeBin),tau_az(rangeBin),prf,size(rgc_dopp,2));
end

% Single-look complex image
slcimg = fftshift(ifft(rgc_dopp.*conj(fft(azRef,[],2)),[],2),2);


figure; imagesc(abs(slcimg))




% Create azimuth reference chirp.
function chirp = getAzimuthChirp(fc,slope,tau,fs,numLines)
% fc : centre frequency
% slope : chirp slope
% tau : pulse duration
% fs : sampling rate
% numLines : number of azimuth lines
dt = 1/fs;
npts = floor(tau*fs);
t = (-npts/2:npts/2-1)*dt;
if(size(t,2) >= numLines)
    phase = 2*pi*fc*t(1:numLines)+pi*slope*t(1:numLines).^2;
else
    phase = 2*pi*fc*t+pi*slope*t.^2;
end
chirp = [exp(1i*phase) zeros(1,numLines-length(phase))];
end



























% % % [Nl, Ns] = size(rangeCompressed);
% % % % Doppler frequency vector after FFT (assumes DC=0)
% % % fdopp = (0:Nl-1)'/Nl*prf;
% % % idx_wrap = fdopp>=prf/2;
% % % fdopp(idx_wrap) = fdopp(idx_wrap) - prf;
% % % 
% % % lambda = 0.03;
% % % Vr = 0.45;
% % % SR = rnggrid(268:290);
% % % 
% % % dopp_R = -2*Vr^2/lambda./SR; % Doppler rate
% % % slc = ifft(rgc_dopp.*exp(1i*pi*fdopp.^2./dopp_R),[],2);
% % % 
% % % figure;imagesc(abs(slc))

% rangeCompressed = zeros(23,140);
% 
% 
% background = zeros(534, 145);
% target = zeros(534, 145);
% 
% cols = 1;
% for ii = 1:145
% 
%     background(:,ii) = sum(backgroundFull(:,cols:(ii*10)),2)/10;
% 
% 
%     target(:,ii) = sum(targetFull(:,cols:(ii*10)),2)/10;
%     cols = cols+10;
% 
% end
% 
% 
% 
% 
% 
% for ii = 1:size(target,2)
% 
%     [respTarget, ~] = rd(target(:,ii));
%     [respBack,~] = rd(background(:,ii));
%     difference = pow2db(abs(respTarget)) - pow2db(abs(respBack));
%     rangeCompressed(:,ii) = difference(268:290);
% 
% end
% 
% figure;imagesc(abs(fftshift(fft(rangeCompressed,[],2))))
% figure;imagesc(densityremap(rangeCompressed))



