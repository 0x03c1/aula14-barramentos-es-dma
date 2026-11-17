# Barramentos, Entrada/Saída, Interrupções e DMA

**Infraestrutura de Hardware · CESAR School · 2026.2**

Hoje você vai medir, no seu próprio computador, quanto custa pedir dados ao sistema operacional. Vamos ler o **mesmo arquivo**, no **mesmo disco**, mudando só uma coisa: quantos bytes pedimos em cada chamada `read()`.

Antes de rodar, anote o seu palpite: entre ler 1 byte por vez e ler 64 KB por vez, a diferença de velocidade vai ser de quanto?

---

## O que tem aqui

| Arquivo | Para que serve |
|---|---|
| `codigo/io.c` | Lê um arquivo com `read()` usando o tamanho de buffer que você escolher. Mede quantas chamadas fez, o tempo e a vazão (MB/s). |
| `codigo/io_fread.c` | A mesma leitura, mas com `fread()` pedindo 1 byte por vez. |
| `codigo/experimento.sh` | Roda tudo de uma vez no **Linux, macOS, WSL ou Git Bash** e gera `resultados.csv`. |
| `codigo/experimento.ps1` | Roda tudo de uma vez no **Windows (PowerShell)** e gera `resultados.csv`. |

Os programas compilam com gcc, clang ou com o compilador do Visual Studio (`cl`).

---

## Como rodar

### Linux (ou WSL2 no Windows)

```bash
sudo apt install build-essential strace     # só na primeira vez (Ubuntu/Debian)
cd codigo
chmod +x experimento.sh
./experimento.sh            # arquivo de 256 MB, limpa o cache antes de cada medição
./experimento.sh 64         # arquivo de 64 MB: termina mais rápido
```

### macOS

```bash
xcode-select --install      # só se ainda não tiver o compilador
cd codigo
chmod +x experimento.sh
./experimento.sh 64
```

O script pede sua senha uma vez para limpar o cache (`sudo purge`). O macOS não tem `strace` nem `/proc`; veja as alternativas na atividade.

### Windows

**Opção recomendada: WSL2.** Abra o Ubuntu do WSL e siga as instruções de Linux. É o único jeito de fazer **todos** os itens (o `strace` só existe no Linux).

**Opção nativa: PowerShell.** Você precisa de um compilador C: gcc (MSYS2 ou WinLibs) ou o Visual Studio. Se for usar o Visual Studio, abra o *Developer PowerShell for VS*. Depois:

```powershell
cd codigo
powershell -ExecutionPolicy Bypass -File .\experimento.ps1 -MB 64
```

O `-ExecutionPolicy Bypass` é necessário porque o Windows bloqueia scripts baixados da internet.

> **Cache no Windows.** O Windows não tem um comando nativo para esvaziar o cache de arquivos. Por padrão o script mede com cache quente, e a conclusão sobre o custo da syscall continua valendo. Se quiser medir com cache frio: baixe o [RAMMap](https://learn.microsoft.com/sysinternals/downloads/rammap), coloque o `RAMMap64.exe` na pasta `codigo` e rode o PowerShell **como Administrador**. O script detecta o programa e o usa sozinho.

**Git Bash também funciona:** `./experimento.sh 64` (sempre com cache quente).

---

## Fazendo na mão (para entender cada passo)

O script só automatiza estes comandos. Vale rodar alguns na mão pelo menos uma vez.

```bash
# 1. Cria um arquivo de 256 MB com bytes aleatórios
dd if=/dev/urandom of=dados.bin bs=1M count=256

# 2. Compila
gcc -O2 io.c -o io

# 3. Esvazia o cache do SO (senão você mede a RAM, não o disco)
sync && sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches'     # Linux
sync && sudo purge                                          # macOS

# 4. Mede com um tamanho de buffer
./io dados.bin 4096
```

| Pedaço | O que significa |
|---|---|
| `if=/dev/urandom` | entrada: um gerador infinito de bytes aleatórios |
| `of=dados.bin` | saída: o arquivo que será criado |
| `bs=1M count=256` | 256 blocos de 1 MB = 256 MB |
| `sync` | grava no disco o que ainda está pendente na memória |
| `sudo sh -c '…'` | roda o comando inteiro como root, **inclusive o `>`**. `sudo echo 3 > …` falha, porque o `>` é executado pelo seu shell, sem root |
| `echo 3` | 1 = cache de páginas, 2 = dentries e inodes, 3 = os dois |
| `-O2` | otimização nível 2, a mesma de programas de produção |
| `./io dados.bin 4096` | lê `dados.bin` com buffer de 4096 bytes |

A saída tem este formato:

```
buffer=   4096 B |      65536 syscalls |    0.140 s |   1917.4 MB/s | 2.136 us/read
```

---

## Atividade (em duplas): entrega até o fim da aula

### Parte A: medir

1. Rode o experimento para os buffers **1, 16, 256, 4096, 65536 e 1048576 bytes**, limpando o cache antes de cada medição. O script faz isso e gera `resultados.csv`.
2. Monte a tabela: **buffer | syscalls | tempo (s) | MB/s**.
3. Calcule o custo de **uma** `read()`: tempo do buffer de 1 B ÷ número de syscalls = ____ µs.

### Parte B: investigar

4. **Plote** a vazão (MB/s) em função do tamanho do buffer, com o eixo X em escala log. Marque onde a curva para de subir (o platô). Esse número tem algum significado? *(Dica: Aula 13.)*
5. **Compare com `fread()`.** Rode `./io_fread dados.bin`. Por que ele **não** é centenas de vezes mais lento, se também pede 1 byte por vez? Quantas `read()` reais aconteceram?
   - Linux/WSL: `strace -c -e trace=read ./io_fread dados.bin`
   - macOS/Windows nativo: não há `strace`. Faça este item no WSL, num Linux de um colega, ou responda com base no tamanho do buffer interno da biblioteca C.
6. **Interrupções ao vivo.** Deixe um terminal mostrando as interrupções. Em outro terminal, copie um arquivo grande. As interrupções aumentaram na proporção dos bytes copiados? Explique usando DMA.

   | Sistema | Terminal 1 (observar) | Terminal 2 (copiar) |
   |---|---|---|
   | Linux/WSL | `watch -d -n1 "grep -E 'nvme\|eth\|enp\|wlan' /proc/interrupts"` | `cp dados.bin copia.bin && sync` |
   | macOS | `sudo powermetrics --samplers interrupts -i 1000` (veja a nota abaixo) | `cp dados.bin copia.bin && sync` |
   | Windows | `while ($true) { (Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'").InterruptsPersec; Start-Sleep 1 }` | `Copy-Item dados_64MB.bin copia.bin` |

   > **macOS:** o `powermetrics` mostra no máximo o total de interrupções por CPU, sem separar por dispositivo, e em alguns Macs não mostra nada. Se não aparecer contagem, faça este item com uma dupla que tenha Linux, WSL ou Windows. No Windows o contador também é o total do sistema: compare o valor parado com o valor durante a cópia.

### Cuidados

- **Nunca rode `strace` com buffer de 1 B no arquivo de 256 MB**: pode levar horas. Use um arquivo pequeno: `head -c 1M dados.bin > mini.bin` e `strace -c -e trace=read ./io mini.bin 1`.
- O buffer de 1 B é lento por natureza: no arquivo de 256 MB pode levar alguns minutos. Use `./experimento.sh 64` se o tempo estiver curto. A vazão em MB/s não depende do tamanho do arquivo.
- Sem limpar o cache, a segunda execução lê da RAM e você conclui que "o disco é rapidíssimo". É o erro de medição mais comum em testes de E/S.

### Entrega: 1 página em PDF, com os nomes da dupla no topo

- Gráfico com o platô marcado
- Tabela e custo de uma `read()` em µs (mostre a conta)
- Respostas dos itens 5 e 6
- As 4 perguntas obrigatórias:
  1. O que foi medido?
  2. Como foi medido?
  3. Por que esse resultado?
  4. Qual teoria explica?

| Critério | Pontos |
|---|---|
| Tabela completa com os 6 buffers | 2 |
| Gráfico com o platô marcado e explicado | 2 |
| Custo de uma `read()` em µs, com a conta | 1 |
| `fread()`: número de `read()` reais e o porquê | 2 |
| Interrupções × bytes, explicadas com DMA | 1 |
| As 4 perguntas obrigatórias | 2 |
| **Total** | **10** |

---

## Problemas comuns

| Sintoma | Causa e solução |
|---|---|
| `command not found: gcc` | Linux: `sudo apt install build-essential`. macOS: `xcode-select --install`. Windows: use o WSL2 ou instale o gcc. |
| `Permission denied` no `drop_caches` | Faltou o `sudo sh -c '…'` (veja a tabela acima). |
| O buffer de 1 B "travou" | Não travou: são centenas de milhões de chamadas. Espere ou use o arquivo de 64 MB. |
| `Segmentation fault` ou `uso:` | Faltou o segundo argumento: `./io dados.bin 4096`. |
| Windows: "a execução de scripts foi desabilitada" | Rode com `powershell -ExecutionPolicy Bypass -File .\experimento.ps1`. |
| Sem `sudo` no laboratório | `SEM_LIMPAR=1 ./experimento.sh 64`. A diferença entre 1 B e 64 KB continua aparecendo; só o teto do platô muda. |

---

## Referências

- STALLINGS, W. *Arquitetura e Organização de Computadores*. Pearson. Cap. 3 e 7 (Barramentos e E/S).
- TANENBAUM, A. *Organização Estruturada de Computadores*. Cap. 3.
- Ferramentas: `lspci -vv`, `strace -c`, `/proc/interrupts`, `dd`, `iostat`.
