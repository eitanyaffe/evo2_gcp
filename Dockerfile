FROM nvcr.io/nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04

# Install Python 3.11 and pip
RUN apt-get update && apt-get install -y \
    wget build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev \
    libssl-dev libreadline-dev libffi-dev curl libbz2-dev xz-utils \
 && wget https://www.python.org/ftp/python/3.11.9/Python-3.11.9.tgz \
 && tar -xf Python-3.11.9.tgz \
 && cd Python-3.11.9 && ./configure --enable-optimizations && make -j$(nproc) && make altinstall \
 && ln -sf /usr/local/bin/python3.11 /usr/bin/python3 \
 && python3 -m ensurepip && python3 -m pip install --upgrade pip

# install git
RUN apt-get update && apt-get install -y git && rm -rf /var/lib/apt/lists/*

# get requirements
COPY requirements.txt .

# requirements
RUN pip install --no-cache-dir setuptools wheel
RUN pip install --no-cache-dir `cat requirements.txt | grep ^torch`
RUN pip install --no-cache-dir `cat requirements.txt | grep ^numpy`
RUN pip install --no-cache-dir ninja
RUN pip install --no-cache-dir -r requirements.txt

# evo2
RUN pip install --no-cache-dir evo2
