# Changelog

Todas as mudanças importantes deste projeto serão documentadas aqui.

## [1.4] - 2024-02-12
### Added
- Opção de testes de conectividade de rede ao SUSE Manager (`-nT`), incluindo ping, nc, nslookup/dig/host e traceroute.
- Backup automático de arquivos e diretórios críticos antes da limpeza.
- Remoção de pacotes relacionados ao SUSE Manager client (zypper/yum).
- Limpeza de arquivos de configuração, logs e identificadores únicos do sistema.
- Download e instalação automática do certificado SSL do SUSE Manager.
- Opções para executar apenas etapas específicas: backup, limpeza, reset de identificadores.
- Log detalhado de todas as operações realizadas.
- Ajuda detalhada via `-h` e exemplos de uso.

### Changed
- Estrutura do script modularizada em funções.
- Detecção automática do SUSE Manager via arquivos de configuração ou variável de ambiente.

### Fixed
- Correções em mensagens de erro e tratamento de ausência de parâmetros obrigatórios.

---