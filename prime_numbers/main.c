#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <time.h>

struct Stats {
    uint64_t loops;
    uint64_t tries;
    uint64_t max_tries;
    clock_t duration;
    clock_t max_duration;
};

struct Stats newStats() {
    struct Stats s;
    s.loops = 0;
    s.tries = 0;
    s.max_tries = 0;
    s.duration = 0;
    s.max_duration = 0;

    return s;
}

void updateStats(struct Stats* s, uint64_t tries, clock_t duration ) {
    s->loops += 1;
    
    s->tries += tries;
    if (tries > s->max_tries) {
        s->max_tries = tries;
    }

    s->duration += duration;
    if (duration > s->max_duration) {
        s->max_duration = duration;
    }
}

void importStats(struct Stats* from, struct Stats* to) {
    to->loops += from->loops;

    to->tries += from->tries;
    if (from->max_tries > to->max_tries) {
        to->max_tries = from->max_tries;
    }

    to->duration += from->duration;
    if (from->max_duration > to->max_duration) {
        to->max_duration = from->max_duration;
    }
}

void resetStats(struct Stats* s) {
    s->loops = 0;
    s->tries = 0;
    s->max_tries = 0;
    s->duration = 0;
    s->max_duration = 0;
}

void printStats(uint64_t id, struct Stats* s) {
    if (s->loops > 0) {
        float mean_tries = s->tries / (1.*s->loops);
        float mean_duration = s->tries / (1.*s->loops);

        printf("id: %llu, total_tries:%llu, mean_tries:%f, max_tries:%llu, total_dur_ms:%lu, mean_dur_ms:%f, max_dur_ms:%lu\n", id, s->tries, mean_tries, s->max_tries, s->duration, mean_duration, s->max_duration);
    }
}

void printAndResetStats(uint64_t id, struct Stats* s) {
    printStats(id, s);
    resetStats(s);
}

bool isPrime(uint64_t val, struct Stats* s) {
    clock_t start = clock();

    int i;
    bool is_prime = true;

    for(i = 2; i < val; i++) {
        if (val % i == 0) {
            is_prime = false;
            break;
        }
    } 

    updateStats(s, i - 2, clock() - start);
    return is_prime;
}

int main() {
    struct Stats local_stats = newStats();
    struct Stats global_stats = newStats();

    int items = 100000;
    int pos = 0;
    uint64_t* primeNumbers = malloc(items * sizeof(uint64_t));

    int i;
    int i_max = 1000000;

    for (i = 1; i < i_max; i++) {
        if (isPrime(i, &local_stats)) {
            if (pos + 1 == items) {
                return -1;
            }
            primeNumbers[pos] = i;
            pos++;
        }

        if (i%1000 == 0) {
            importStats(&local_stats, &global_stats);
            printAndResetStats(i, &local_stats);
        }
    }

    importStats(&local_stats, &global_stats);
    printStats(i, &global_stats);
    
    return 0;
}
