// nb_macrotonic v0.1 @sonoCircuit - based on supertonic @infinitedigits

NB_macrotonic {

	*initClass {

		var voxs, glbParams, voxParams, nozBuf;
		var numVoices = 6;

		StartUp.add {

			glbParams = Dictionary.newFrom([
				\mainAmp, 1,
				\level, 1,
				\pan, 0,
				\sendA, 0,
				\sendB, 0,
				\mix, 0.6,
				\distAmt, 2,
				\eQFreq, 632.4,
				\eQGain, -12,
				\oscAtk, 0,
				\oscDcy, 0.500,
				\oscWave, 0,
				\oscFreq, 120,
				\modMode, 0,
				\modRate, 400,
				\modAmt, 18,
				\nEnvAtk, 0.026,
				\nEnvDcy, 0.800,
				\nFilFrq, 2000,
				\nFilQ, 2,
				\nFilMod, 0,
				\nEnvMod, 2,
				\nStereo, 1,
				\oscVel, 1,
				\nVel, 0.2,
				\modVel, 1,
				\lpf_hz, 20000,
				\lpf_rz, 1
			]);

			voxParams = Array.fill(numVoices, { Dictionary.newFrom(glbParams) });
			voxs = Array.newClear(numVoices);
			nozBuf = Buffer.loadCollection(Server.default, FloatArray.fill(288000, { if(2.rand > 0) {1.0} {-1.0} }));

			SynthDef(\nb_macroT,{
				arg outBus, sendABus, sendBBus, nBuf,
				vel = 0.5, mainAmp = 1, level = 1, pan = 0, sendA = 0, sendB = 0, distAmt = 0.2, eQFreq = 632.4, eQGain = -20, mix = 0.8,
				oscWave = 0, oscFreq = 54, modMode = 0, modRate = 400, modAmt = 18, oscAtk = 0, oscDcy = 0.500,
				nFilFrq = 1000, nFilQ = 2.5, nFilMod = 0, nEnvMod = 0, nStereo = 1, nEnvAtk = 0.026, nEnvDcy = 0.200,
				oscVel = 1, nVel = 1, modVel = 1, lpf_hz = 20000, lpf_rz = 1;

				// variables
				var osc, noz, nozPostF, snd, pitchMod, numClaps, dAction, wn1, wn2,
				clapFreq, decayer, envO, envX, envL, envD, boost, att, lpf_q;

				// rescale and clamp
				vel = vel.linlin(0, 1, 0, 2);
				eQFreq = eQFreq.clip(20, 20000);
				lpf_hz = lpf_hz.clip(20, 20000);
				lpf_q = lpf_rz.linlin(0, 1, 1, 0.05);
				clapFreq = (4311 / (nEnvAtk + 28.4)) + 11.44;
				decayer = SelectX.kr(distAmt, [0.05, distAmt * 0.3]);

				// envelopes
				dAction = Select.kr(((oscAtk + oscDcy) > (nEnvAtk + nEnvDcy)), [0, 2]);
				envO = EnvGen.ar(Env.new([0.0001, 1, 0.9, 0.0001], [oscAtk, oscDcy * decayer, oscDcy], \exponential), doneAction: dAction);
				envX = EnvGen.ar(Env.new([0.001, 1, 0.0001], [nEnvAtk, nEnvDcy], \exponential), doneAction:(2 - dAction));
				envL = EnvGen.ar(Env.new([0.0001, 1, 0.9, 0.0001], [nEnvAtk, nEnvDcy * decayer,nEnvDcy * (1 - decayer)], \linear));
				envD = Decay.ar(Impulse.ar(clapFreq), clapFreq.reciprocal, 0.85, 0.15) * Trig.ar(1, nEnvAtk + 0.001) + EnvGen.ar(
					Env.new([0.001, 0.001, 1, 0.0001], [nEnvAtk,0.001, nEnvDcy], \exponential)
				);

				// pitch modulation
				pitchMod = Select.ar(modMode, [
					Decay.ar(Impulse.ar(0.0001), (2 * modRate).reciprocal), // decay
					SinOsc.ar(modRate, pi), // sine
					LFNoise0.ar(4 * modRate).lag((4 * modRate).reciprocal) // random
				]);
				pitchMod = pitchMod * modAmt * modVel * vel;
				oscFreq = ((oscFreq).cpsmidi + pitchMod).midicps;

				// noise playback
				wn1 = PlayBuf.ar(1, nBuf, startPos: IRand.new(0, 288000), loop: 1);
				wn2 = PlayBuf.ar(1, nBuf, startPos: IRand.new(0, 288000), loop: 1);

				// oscillator
				osc = Select.ar(oscWave, [
					SinOsc.ar(oscFreq),
					LFTri.ar(oscFreq) * 0.5,
					SawDPW.ar(oscFreq) * 0.5,
				]);
				osc = Select.ar(modMode > 1, [osc, SelectX.ar(oscDcy < 0.1, [LPF.ar(wn2, modRate), osc])]) * envO;
				osc = (osc * oscVel * vel).softclip;

				// noise source
				noz = Select.ar(nStereo, [wn1, [wn1, wn2]]);
				// noise filter
				nozPostF = Select.ar(nFilMod,
					[
						BLowPass.ar(noz, nFilFrq, Clip.kr(1/nFilQ, 0.5, 3)),
						BBandPass.ar(noz, nFilFrq, Clip.kr(2/nFilQ, 0.1, 6)),
						BHiPass.ar(noz, nFilFrq, Clip.kr(1/nFilQ, 0.5, 3))
					]
				);
				nozPostF = SelectX.ar((0.1092 * nFilQ.log + 0.0343), [nozPostF, SinOsc.ar(nFilFrq)]);
				// noise env & vel
				noz = Splay.ar(nozPostF * Select.ar(nEnvMod, [envX, envL, envD]));
				noz = (noz * nVel * vel).softclip * -6.dbamp;

				// mix oscillator and noise
				snd = XFade2.ar(osc, noz, mix);
				// distortion
				snd = (snd * (1 - distAmt) + ((snd * distAmt.linlin(0, 1, 12, 24).dbamp).softclip * distAmt));
				snd = snd * distAmt.linlin(0, 1, 0, -6).dbamp;
				// eq after distortion
				snd = BPeakEQ.ar(snd, eQFreq, 1, eQGain);
				// remove sub freq
				snd = HPF.ar(snd, 20);
				// final level
				snd = snd * level * mainAmp * -9.dbamp;
				// lowpass
				snd = RLPF.ar(snd, lpf_hz, lpf_q);
				// pan
				snd = Balance2.ar(snd[0], snd[1], pan);
				// output
				Out.ar(sendABus, sendA * snd);
				Out.ar(sendBBus, sendB * snd);
				Out.ar(outBus, snd);
			}).add;


			OSCFunc.new({ |msg|
				var idx = msg[1].asInteger;
				var vel = msg[2].asFloat;
				var syn;

				if (voxs[idx] != nil) {
					voxs[idx].free;
				};

				syn = Synth.new(\nb_macroT,
					[
						\vel, vel,
						\nBuf, nozBuf,
						\sendABus, (~sendA ? Server.default.outputBus),
						\sendBBus, (~sendB ? Server.default.outputBus)
					] ++ voxParams[idx].getPairs
				);

				syn.onFree {
					if (voxs[idx] != nil && voxs[idx] === syn) {
						voxs.put(idx, nil);
					};
				};

				voxs.put(idx, syn);

			}, "/nb_macrotonic/trig");

			OSCFunc.new({ |msg|
				var idx = msg[1].asInteger;
				var key = msg[2].asSymbol;
				var val = msg[3].asFloat;
				voxParams[idx][key] = val;
			}, "/nb_macrotonic/set_param");

			OSCFunc.new({ |msg|
				var val = msg[1].asFloat;
				numVoices.do{ |idx|
					voxParams[idx][\mainAmp] = val
				};
			}, "/nb_macrotonic/set_main_amp");

			OSCFunc.new({ |msg|
				var val = msg[1].asFloat;
				numVoices.do{ |idx|
					voxParams[idx][\lpf_hz] = val
				};
			}, "/nb_macrotonic/set_cutoff");

			OSCFunc.new({ |msg|
				var val = msg[1].asFloat;
				numVoices.do{ |idx|
					voxParams[idx][\lpf_rz] = val
				};
			}, "/nb_macrotonic/set_resonance");

		};
	}
}
