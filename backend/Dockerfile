# Usar imagem base Python 3.9 slim
FROM python:3.9-slim

# Diretório de trabalho dentro do container
WORKDIR /app

# Copiar os arquivos do backend para o container
COPY . .

# Instalar dependências
RUN pip install --no-cache-dir -r requirements.txt

# Expor a porta 5000
EXPOSE 5000

# Comando para iniciar o backend
CMD ["python", "app.py"]

