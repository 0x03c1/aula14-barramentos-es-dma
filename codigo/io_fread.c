/*
 * io_fread.c — mesma leitura do io.c, agora com fread() pedindo 1 byte por vez.
 *
 * Pergunta da atividade: por que isto NÃO é centenas de vezes mais lento
 * que ler em blocos, se também pede 1 byte por chamada?
 *
 * Uso:   ./io_fread <arquivo>
 */
#include <stdio.h>

#ifdef _WIN32
  #include <windows.h>
  static double agora(void) {
      LARGE_INTEGER f, t;
      QueryPerformanceFrequency(&f);
      QueryPerformanceCounter(&t);
      return (double)t.QuadPart / (double)f.QuadPart;
  }
#else
  #include <time.h>
  static double agora(void) {
      struct timespec t;
      clock_gettime(CLOCK_MONOTONIC, &t);
      return t.tv_sec + t.tv_nsec / 1e9;
  }
#endif

int main(int argc, char **argv) {
    if (argc < 2) { fprintf(stderr, "uso: %s <arquivo>\n", argv[0]); return 1; }
    FILE *f = fopen(argv[1], "rb");          /* "rb": modo binário (importa no Windows) */
    if (!f) { perror("fopen"); return 1; }

    char c;
    double total = 0;

    double t0 = agora();
    while (fread(&c, 1, 1, f) == 1)          /* 1 byte por chamada de fread() */
        total++;
    double seg = agora() - t0;
    if (seg <= 0) seg = 1e-9;

    printf("fread 1B | %10.0f freads | %8.3f s | %8.1f MB/s\n",
           total, seg, (total / 1e6) / seg);
    fclose(f);
    return 0;
}
