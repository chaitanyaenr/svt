FROM openshift/origin-tests:v4.0

# Dockerfile for pbench-controller
FROM centos:latest
MAINTAINER Naga Ravi Chaitanya Elluri <nelluri@redhat.com>

ENV KUBECONFIG /root/.kube/config
ENV HOME /root
USER root

# Install dependencies and clone svt repo
RUN yum clean all && yum install epel-release -y && yum install -y python-pip python-s3transfer python-boto3 python-rbd python-flask git ansible which golang wget tmux jq && \
    git clone https://github.com/chaitanyaenr/svt.git /root/svt && cd /root/svt && git checkout starter_cluster && \
    curl -L https://mirror.openshift.com/pub/openshift-v3/clients/4.1.0-201904090034.git.0.1016bda.el7/linux/oc.tar.gz | tar -zx && mv oc /usr/local/bin

# Copy openshift-tests binary from openshift/origin-tests:v4.0 image
COPY --from=0 /bin/openshift-tests /bin/openshift-tests
COPY --from=0 /bin/openshift-tests /usr/bin/openshift-tests

# Copy test script
COPY run.sh /root/run.sh
RUN chmod +x /root/run.sh
RUN mkdir -p /root/.kube
RUN chmod 777 -R /root && chmod u+t -R /root

ENTRYPOINT ["/root/run.sh"]
