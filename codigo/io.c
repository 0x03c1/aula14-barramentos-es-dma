/*
 * io.c — Aula 14: quanto custa uma chamada de sistema read()?
 *
 * Lê um arquivo inteiro com read(), usando um buffer do tamanho pedido,
 * e mede: quantas chamadas foram feitas, o tempo total e a vazão (MB/s).
 *
 * Uso:   ./io <arquivo> <tamanho_do_buffer_em_bytes>
 * Ex.:   ./io dados.bin 4096
 *
 * Compila em Linux, macOS e Windows (gcc, clang ou MSVC):
 *   gcc -O2 io.c -o io          (Linux / macOS / Windows com MinGW)
 *   cl /O2 /nologo io.c         (Windows com Visual Studio)
 */
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>

#ifdef _WIN32
  /* No Windows, read()/open() vêm de <io.h> e têm nomes com "_".      */
  #include <io.h>
  #include <windows.h>
  #define abrir(caminho)       _open((caminho), _O_RDONLY | _O_BINARY)
  #define ler(fd, buf, n)      _read((fd), (buf), (unsigned int)(n))
  #define fechar(fd)           _close(fd)
  /* _O_BINARY é OBRIGATÓRIO: em modo texto o Windows converte \r\n e
     PARA de ler no byte 0x1A (Ctrl+Z), que aparece em dados aleatórios. */
  static double agora(void) {
      LARGE_INTEGER f, t;
      QueryPerformanceFrequency(&f);
      QueryPerformanceCounter(&t);
      return (double)t.QuadPart / (double)f.QuadPart;
  }
#else
  #include <unistd.h>
  #include <time.h>
  #define abrir(caminho)       open((caminho), O_RDONLY)
  #define ler(fd, buf, n)      read((fd), (buf), (n))
  #define fechar(fd)           close(fd)
  static double agora(void) {           /* relógio que nunca anda para trás */
      struct timespec t;
      clock_gettime(CLOCK_MONOTONIC, &t);
      return t.tv_sec + t.tv_nsec / 1e9;
  }
#endif

int main(int argc, char **argv) {
    if (argc < 3) {
        fprintf(stderr, "uso: %s <arquivo> <buffer_em_bytes>\n", argv[0]);
        return 1;
    }
    size_t buf_sz = (size_t)atol(argv[2]);   /* tamanho do buffer pedido   */
    if (buf_sz == 0) { fprintf(stderr, "buffer precisa ser > 0\n"); return 1; }
    char *buf = malloc(buf_sz);              /* reserva o buffer na RAM    */
    if (!buf) { fprintf(stderr, "sem memória\n"); return 1; }

    int fd = abrir(argv[1]);                 /* abre o arquivo (syscall)   */
    if (fd < 0) { perror("open"); return 1; }

    double total = 0, chamadas = 0;
    long n;

    double t0 = agora();                     /* cronômetro: início         */
    while ((n = (long)ler(fd, buf, buf_sz)) > 0) {   /* cada volta = 1 syscall */
        total += n;
        chamadas++;
    }
    double seg = agora() - t0;               /* cronômetro: fim            */

    if (n < 0) { perror("read"); return 1; }
    if (chamadas == 0) { fprintf(stderr, "arquivo vazio\n"); return 1; }
    if (seg <= 0) seg = 1e-9;

    printf("buffer=%7.0f B | %10.0f syscalls | %8.3f s | %8.1f MB/s | %.3f us/read\n",
           (double)buf_sz, chamadas, seg, (total / 1e6) / seg, seg * 1e6 / chamadas);

    fechar(fd);
    free(buf);
    return 0;
}
