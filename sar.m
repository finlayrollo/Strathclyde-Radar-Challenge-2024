% This script demonstrates how to setup the Phaser System as an FMCW radar.
% 
% % Setup:
%
% Connect the Vivaldi antenna to Phaser SMA Out2. Place the Vivaldi antenna
% next to the Phaser.
%
% Notes:
%
% Run this script to generate a range doppler plot, as
% well as a few plots that illustrate the timing of a pulse repitition
% interval. The first time this script is run, the data collection may not
% occur properly.
%
% Copyright 2023 The MathWorks, Inc.


%% Clear, close figures, turn off warnings
% clear; close all;
warning('off','MATLAB:system:ObsoleteSystemObjectMixin')

%% Put some requirements on the system

maxRange = 10; % 100 m max range, use the system in a room
rangeResolution = 1/3; % Range resolution of 1/3 m
maxSpeed = 4; % Max speed we expect is 5 m/s, somebody moving towards the radar
speedResolution = 1/2; % Speed resolution of 1/2 m/s

%% Determine some parameter values based on system requirements, based on the
% following example - https://www.mathworks.com/help/radar/ug/automotive-adaptive-cruise-control-using-fmcw-technology.html

fc = 10e9; % rf carrier freqclcuency is ~10 GHz
lambda = physconst("LightSpeed") / fc;
rampbandwidth = ceil(rangeres2bw(rangeResolution)/1e6)*1e6; % get ramp bandwidth for required range resolution, conviniently this brings us close to the maximum for the Phaser
fmaxdop = speed2dop(2*maxSpeed,lambda); % Maximum doppler shift depends on max speed we want to resolve, multiply by 2 for 2 way propagation
prf = 2*fmaxdop; % PRF needs to be set to unambiguously resolve max speed
nPulses = 1000; % Number of pulses set to for speed resolution
tpulse = ceil((1/prf)*1e3)*1e-3; % Pulse time, round up to the nearest ms
tsweep = getFMCWSweepTime(tpulse,tpulse); % Sweep across as much of the pulse as possible
sweepslope = rampbandwidth / tsweep; % Slope of the FMCW sweep
fmaxbeat = sweepslope * range2time(maxRange); % Max beat frequency in this case we only consider the f offset due to range delay. With faster targets, you need to consider doppler
fs = max(ceil(2*fmaxbeat),520834); % Set sample rate based on the maximum beat frequency or the minimum rate of the pluto.
%fs = ceil(2*fmaxbeat); % Set sample rate based on the maximum beat frequency or the minimum rate of the pluto.

nSamples = ceil(tpulse * nPulses * fs); % Get the total number of samples in a PRP

%% Setup pluto

% Setup the pluto
[rx,tx] = setupPluto();

% Setup pluto sampling
rx.SamplesPerFrame = nSamples;
rx.SamplingRate = fs;

% Setup transmitter
tx.SamplingRate = fs;
tx.EnabledChannels = [1,2];
tx.CenterFrequency = rx.CenterFrequency;
tx.AttenuationChannel0 = -3;
tx.AttenuationChannel1 = -3;
tx.EnableCyclicBuffers = true;
tx.DataSource = "DMA";

% This is where you could create some modulation scheme, we just use a
% constant amplitude baseband signal.
amp = 0.9 * 2^15;
txWaveform = amp*ones(nSamples,2);

%% Setup the Phaser

% Setup beamformers all to max gain with no phase shifts
bf = setupPhaser(rx,fc);
bf.RxPowerDown(:) = 0;
bf.RxGain(:) = 127;

% Setup ADF4159
bf.Frequency = (fc+rx.CenterFrequency)/4;
BW = rampbandwidth / 4; 
num_steps = 2^9;
bf.FrequencyDeviationRange = BW;
bf.FrequencyDeviationStep = ((BW) / num_steps);
bf.FrequencyDeviationTime = tsweep*1e6; % convert to us
bf.RampMode = "continuous_sawtooth"; % use a single sawtooth, other waveforms are available
bf.TriggerEnable = true;  % start a ramp with TXdata
bf.EnablePLL = true;
bf.EnableTxPLL = true;
bf.EnableOut1 = false; % send transmit out of SMA2

%% Setup the TDD engine

bf_TDD = setupTddEngine();
tStartRamp = 0;
tStartCollection = 0;
phaserEnable = 1;
bf_TDD.PhaserEnable = phaserEnable; % enable triggered mode
bf_TDD.Enable = 0;   % TDD must be disabled before changing properties
bf_TDD.EnSyncExternal = 1;
bf_TDD.StartupDelay = 0;
bf_TDD.SyncReset = 0;
bf_TDD.FrameLength = tpulse*1e3;  %frame length in ms
bf_TDD.BurstCount = nPulses; % Number of pulses in a CPI
bf_TDD.Ch0Enable = 1;
bf_TDD.Ch0Polarity = 0;
bf_TDD.Ch0On = tStartRamp; % Time to start PLL sweep in a frame
bf_TDD.Ch0Off = tsweep; % this doesn't need to be tsweep, this just ensures control pulse ends before next PLL pulse starts
bf_TDD.Ch1Enable = 1;
bf_TDD.Ch1Polarity = double(~phaserEnable);
bf_TDD.Ch1On = tStartCollection; % Time to start data collection in a frame
bf_TDD.Ch1Off = tStartCollection+0.1;
bf_TDD.Ch2Enable = 0;
bf_TDD.Ch2Polarity = double(~phaserEnable);
bf_TDD.Ch2On = 0;
bf_TDD.Ch2Off = 0.1;
bf_TDD.Enable = 1;

%% Trigger TDD and Plot


% Capture receive data after Coherent Processing Interval (CPI).




rx();
tx(txWaveform);
bf.Burst=false;
tic

% % This command triggers rail
GeckoMoveTo(1400, 450, 'Com7') 


bf.Burst=true;
toc
bf.Burst=false;
data = rx();
data = arrangePulseData(data,rx,bf,bf_TDD);



%% Disable Triggered Mode

% Disable the TDD engine
phaserEnable = 0;
bf_TDD.PhaserEnable = phaserEnable;
bf_TDD.Enable = 0;
bf_TDD.Ch1Polarity = double(~phaserEnable);
bf_TDD.Ch2Polarity = double(phaserEnable);
bf_TDD.Enable = 1;
bf_TDD.Enable = 0;

