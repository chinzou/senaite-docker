# Use an official Python runtime as a parent image
FROM python:2.7-stretch

# Set one or more individual labels
LABEL maintainer="Mekom Solutions"
LABEL email="info@mekomsolutions.com"
LABEL senaite.core.version="2.0.0rc2"

# Set environment variables
ENV PLONE_MAJOR=5.2 \
    PLONE_VERSION=5.2.2 \
    PLONE_MD5=a603eddfd3abb0528f0861472ebac934 \
    PLONE_UNIFIED_INSTALLER=Plone-5.2.2-UnifiedInstaller \
    SENAITE_HOME=/home/senaite \
    SENAITE_USER=senaite \
    SENAITE_INSTANCE_HOME=/home/senaite/senaitelims \
    SENAITE_DATA=/data \
    SENAITE_FILESTORAGE=/data/filestorage \
    SENAITE_BLOBSTORAGE=/data/blobstorage

# Create the senaite user
RUN useradd --system -m -d $SENAITE_HOME -U -u 500 $SENAITE_USER

# Create direcotries
RUN mkdir -p $SENAITE_INSTANCE_HOME $SENAITE_FILESTORAGE $SENAITE_BLOBSTORAGE

# Copy the package config
COPY resources/packages.txt /

# Install package dependencies
RUN apt-get update && apt-get install -y --no-install-recommends $(grep -vE "^\s*#" /packages.txt  | tr "\n" " ")

# Fetch unified installer
RUN wget -O Plone.tgz https://launchpad.net/plone/$PLONE_MAJOR/$PLONE_VERSION/+download/$PLONE_UNIFIED_INSTALLER.tgz \
    && echo "$PLONE_MD5 Plone.tgz" | md5sum -c - \
    && tar -xzf Plone.tgz \
    && cp -rv /$PLONE_UNIFIED_INSTALLER/base_skeleton/* $SENAITE_INSTANCE_HOME \
    && cp -v /$PLONE_UNIFIED_INSTALLER/buildout_templates/buildout.cfg $SENAITE_INSTANCE_HOME/buildout-base.cfg \
    && cd $SENAITE_HOME \
    && rm -rf /$PLONE_UNIFIED_INSTALLER /Plone.tgz

# Change working directory
WORKDIR $SENAITE_INSTANCE_HOME

# Copy Buildout
COPY resources/requirements.txt resources/versions.cfg resources/buildout.cfg resources/develop.cfg ./

RUN chown -R senaite:senaite $SENAITE_INSTANCE_HOME $SENAITE_FILESTORAGE $SENAITE_BLOBSTORAGE

RUN git clone  https://github.com/mekomsolutions/plone.initializer.git $SENAITE_INSTANCE_HOME/src/plone.initializer && cd $SENAITE_INSTANCE_HOME/src/plone.initializer && git checkout main
RUN git clone  https://github.com/mekomsolutions/senaite.indexer.git $SENAITE_INSTANCE_HOME/src/senaite.indexer && cd $SENAITE_INSTANCE_HOME/src/senaite.indexer && git checkout main

# Buildout
RUN pip install -r requirements.txt \
    && buildout -c develop.cfg\
    && ln -s $SENAITE_FILESTORAGE/ var/filestorage \
    && ln -s $SENAITE_BLOBSTORAGE/ var/blobstorage \
    && chown -R senaite:senaite $SENAITE_HOME $SENAITE_DATA

# Mount external volume
VOLUME /data

# Copy startup scripts
COPY resources/docker-initialize.py resources/docker-entrypoint.sh /

# Expose instance port
EXPOSE 8080

# Add instance healthcheck
HEALTHCHECK --interval=1m --timeout=5s --start-period=1m \
  CMD nc -z -w5 127.0.0.1 8080 || exit 1

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["start"]
