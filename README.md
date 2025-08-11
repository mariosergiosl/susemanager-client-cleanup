# susemanager-client-cleanup

Remove completamente um cliente SUSE Manager do sistema, incluindo serviços, pacotes, arquivos de configuração e identificadores únicos.

## Tabela de Conteúdo

- [Descrição](#descrição)
- [Pré-requisitos](#pré-requisitos)
- [Instalação](#instalação)
- [Uso](#uso)
- [Opções](#opções)
- [Exemplos](#exemplos)
- [Fluxo de Execução](#fluxo-de-execução)
- [Disclaimer](#disclaimer)
- [Autor](#autor)
- [Licença](#licença)
- [Referências](#referências)

## Descrição

Este script deve ser usado em sistemas clonados, com problemas de registro ou configuração do cliente SUSE Manager.

## Pré-requisitos

- Bash
- zypper
- nc (netcat)
- wget
- sudo
- tar
- awk, grep, cut, uuidgen, dbus-uuidgen, systemd-machine-id-setup

## Instalação

```bash
git clone https://github.com/mariosergiosl/susemanager-client-cleanup.git
cd susemanager-client-cleanup
chmod +x susemanager-client-cleanup_1.4.sh
```

## Uso

```bash
sudo ./susemanager-client-cleanup_1.4.sh [OPÇÕES]
```

## Opções

| Opção         | Descrição                                                                 |
|---------------|---------------------------------------------------------------------------|
| `-A`          | Executa todas as etapas (backup, limpeza, reset de identificadores).       |
| `-h`          | Exibe esta mensagem de ajuda.                                              |
| `-nB`         | Não faz backup da configuração do sistema.                                |
| `-nC`         | Não executa a limpeza (remoção de pacotes e arquivos).                    |
| `-oC`         | Executa apenas a limpeza.                                                 |
| `-nT`         | Executa testes de conectividade de rede com o servidor SUSE Manager.       |
| `-s <server>` | Informa o hostname/IP do servidor SUSE Manager.                           |
| `-nD`         | Não baixa o certificado SSL do SUSE Manager.                              |

## Exemplos

```bash
sudo ./susemanager-client-cleanup_1.4.sh -A
sudo ./susemanager-client-cleanup_1.4.sh -oC -nB
sudo ./susemanager-client-cleanup_1.4.sh -nT -s my.server.com
```

## Fluxo de Execução

1. **Testes de rede** (opcional)
2. **Backup** dos arquivos de configuração
3. **Parada de serviços** relacionados ao SUSE Manager
4. **Remoção de pacotes** e repositórios
5. **Limpeza de arquivos** e logs
6. **Reset de identificadores** do sistema
7. **Download do certificado SSL** (opcional)
8. **Geração de logs** e compactação dos arquivos de backup

## Disclaimer

Este script é fornecido "no estado em que se encontra", sem garantias. Use por sua conta e risco.

## Autor

Mario Luz <mario.luz[at]suse.com>

## Licença

MIT License

## Referências

- [How to deregister a SUSE Manager Client](https://www.suse.com/support/kb/doc/?id=000018170)
- [A registered client system disappeared from SUSE Manager](https://www.suse.com/support/kb/doc/?id=000018072)
- [zypper SSL certificate problem](https://www.suse.com/support/kb/doc/?id=000018620)
- [Bootstrap fails with ImportError](https://www.suse.com/support/kb/doc/?id=000018753)
- [Bootstrap Internal Server Error](https://www.suse.com/support/kb/doc/?id=000018750)