# Build de executável no Windows

## Instalação de dependências de build

```bat
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements-dev.txt
```

## Gerar executável

```bat
pyinstaller --noconfirm --windowed --name TimesheetBancoHoras main.py
```

O executável será gerado em:

```text
dist\TimesheetBancoHoras\TimesheetBancoHoras.exe
```

## Sobre o Tesseract no `.exe`

Este build empacota o app Python, mas não empacota o Tesseract OCR. Instale o Tesseract na máquina ou configure o caminho em **Preferências**.

Caminho comum:

```text
C:\Program Files\Tesseract-OCR\tesseract.exe
```

## Script pronto

Também existe o arquivo:

```text
build_scripts\build_windows.bat
```

Execute dentro do diretório do projeto.
