# Use official PostgreSQL image as base
FROM postgres:16

# Install build dependencies and pgTAP
RUN apt-get update && apt-get install -y \
    postgresql-server-dev-16 \
    build-essential \
    git \
    cpanminus \
    && rm -rf /var/lib/apt/lists/*

# Install pgTAP from source
RUN git clone https://github.com/theory/pgtap.git /tmp/pgtap \
    && cd /tmp/pgtap \
    && make \
    && make install \
    && rm -rf /tmp/pgtap

# Install TAP::Parser::SourceHandler::pgTAP for pg_prove
RUN cpanm --notest TAP::Parser::SourceHandler::pgTAP

# Set working directory
WORKDIR /workspace

# Copy the extension files
COPY . .

# Set default database credentials
ENV POSTGRES_USER=postgres
ENV POSTGRES_PASSWORD=unsafe
ENV POSTGRES_DB=postgres
