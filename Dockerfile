FROM nvidia/cuda:12.1.0-devel-ubuntu22.04


ARG AWS_OFI_NCCL_VER=1.12.0-aws
ARG AWS_EFA_INSTALLER_VER=1.34.0
ARG BDIR=/tmp/bld
ARG TENSORT_RT_COMMIT=a681853d3803ee5893307e812530b5e7004bb6e1

RUN apt-get update -y

# Install deps
RUN  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    	    python3.10 \
	    python3-pip \
	    curl \
	    git \
	    git-lfs \
	    \
	    libhwloc-dev \
	    libtool \
	    autoconf \
	    openssh-server

# Install EFA libraries
RUN mkdir $BDIR && \
    cd $BDIR && \
    curl -L https://efa-installer.amazonaws.com/aws-efa-installer-${AWS_EFA_INSTALLER_VER}.tar.gz | tar zvx && \
    cd aws-efa-installer && \
    ./efa_installer.sh -k -y -n && \
    cd .. && \
    curl -sL https://github.com/aws/aws-ofi-nccl/releases/download/v${AWS_OFI_NCCL_VER}/aws-ofi-nccl-${AWS_OFI_NCCL_VER}.tar.gz | tar zxv && \
    cd aws-ofi-nccl-${AWS_OFI_NCCL_VER} && \
    ./autogen.sh  && \
    ./configure --with-libfabric=/opt/amazon/efa \
		--with-cuda=/usr/local/cuda \
		--with-mpi=/opt/amazon/openmpi \
		--enable-platform-aws \
		--prefix /usr/local/cuda/efa && \
    make -j && make install && \
    echo /usr/local/cuda/efa/lib > /etc/ld.so.conf.d/aws-ofi-nccl.conf && \
    cd /

ENV PATH /opt/amazon/openmpi/bin/:/opt/amazon/efa/bin:/usr/bin:/usr/local/bin:$PATH
ENV LD_LIBRARY_PATH $LD_LIBRARY_PATH:/usr/local/cuda/efa/lib

#    rm -rf $BDIR && \
#    apt-get remove -y libhwloc-dev libtool autoconf && \
#    apt-get clean && \
#    rm -rf /var/lib/apt/lists/* \
#       /usr/share/doc /usr/share/doc-base \
#       /usr/share/man /usr/share/locale /usr/share/zoneinfo

RUN pip3 install tensorrt_llm -U --pre --extra-index-url https://pypi.nvidia.com
RUN pip3 install --upgrade transformers

# Install TensorRT-LLM
RUN mkdir /workspace && \
    cd /workspace && \
    git clone https://github.com/NVIDIA/TensorRT-LLM.git && \
    cd  TensorRT-LLM && \
    git reset --hard ${TENSORT_RT_COMMIT}



LABEL org.opencontainers.image.authors="monakhov@amazon.com"