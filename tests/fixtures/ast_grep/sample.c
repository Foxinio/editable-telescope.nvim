// TODO: sample comment
#include <stdio.h>
#include <stdlib.h>
#define SIZE 4
#define MAX(a, b) ((a) > (b) ? (a) : (b))

struct point { int x; };

static int helper(int a) {
    char *p = malloc(SIZE);
    char buf[8];
    strcpy(buf, "a string");
    printf("%d\n", a);
    if (p == NULL) goto done;
    int n = sizeof(buf);
    long l = (long)a;
    switch (a) { case 1: break; }
    for (int i = 0; i < n; i++) {}
done:
    free(p);
    return a;
}
