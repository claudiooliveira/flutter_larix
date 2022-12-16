package br.com.devmagic.flutter_larix.conditioner;

class LossHistory {
    long ts;
    long audio;
    long video;

    LossHistory(long ts, long audio, long video) {
        this.ts = ts;
        this.audio = audio;
        this.video = video;
    }

}