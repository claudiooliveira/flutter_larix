package br.com.devmagic.flutter_larix.conditioner;

import java.util.ArrayList;
import java.util.List;

public class TrafficHistory {
        List<Long> values;
        int pos;
        int capacity;
        long prev;

        TrafficHistory(int capacity) {
            this.capacity = capacity;
            values = new ArrayList<>(capacity);
            prev = 0;
        }

        void put(long value) {
            final long delta = value > prev ? value - prev : 0;
            if (values.size() < capacity) {
                values.add(delta);
            } else {
                values.set(pos, delta);
            }
            pos = (pos + 1) % capacity;
            prev = value;
        }

        double avg() {
            if (values.isEmpty()) {
                return 0.0;
            }
            Long sum = 0L;
            for (Long value : values) {
                sum += value;
            }
            return sum.doubleValue() / values.size();
        }

}
