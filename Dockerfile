FROM centos:8
ARG NGINX_VERSION=1.19

RUN yum clean all && yum update -y && yum install -y epel-release && yum module enable -y nginx:${NGINX_VERSION} && yum clean all
RUN yum install -y wget unzip patch rpm-build yum-utils tar gcc make which git nginx libffi-devel rubygems ruby-devel tree geoip-devel gperftools-devel pcre-devel

RUN gem install fpm

WORKDIR /root

RUN wget http://nginx.org/download/nginx-$(nginx -v 2>&1 | sed 's|.*/||g').tar.gz
RUN tar xzvf nginx-$(nginx -v 2>&1 | sed 's|.*/||g').tar.gz

RUN git clone https://github.com/nginx-modules/nginx-statsd

RUN yum install -y {pcre,openssl,libxml2,libxslt,geoip,gperftools,gd}-devel perl-ExtUtils-Embed
RUN cd nginx-$(nginx -v 2>&1 | sed 's|.*/||g') && ./configure --add-dynamic-module=../nginx-statsd --prefix=/usr/share/nginx --sbin-path=/usr/sbin/nginx --modules-path=/usr/lib64/nginx/modules --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log --http-client-body-temp-path=/var/lib/nginx/tmp/client_body --http-proxy-temp-path=/var/lib/nginx/tmp/proxy --http-fastcgi-temp-path=/var/lib/nginx/tmp/fastcgi --http-uwsgi-temp-path=/var/lib/nginx/tmp/uwsgi --http-scgi-temp-path=/var/lib/nginx/tmp/scgi --pid-path=/run/nginx.pid --lock-path=/run/lock/subsys/nginx --user=nginx --group=nginx --with-file-aio --with-ipv6 --with-http_auth_request_module --with-http_ssl_module --with-http_v2_module --with-http_realip_module --with-http_addition_module --with-http_xslt_module=dynamic --with-http_image_filter_module=dynamic --with-http_geoip_module=dynamic --with-http_sub_module --with-http_dav_module --with-http_flv_module --with-http_mp4_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_random_index_module --with-http_secure_link_module --with-http_degradation_module --with-http_slice_module --with-http_stub_status_module --with-http_perl_module=dynamic --with-mail=dynamic --with-mail_ssl_module --with-pcre --with-pcre-jit --with-stream=dynamic --with-stream_ssl_module --with-google_perftools_module --with-debug --with-cc-opt='-O2 -g -pipe -Wall -Wp,-D_FORTIFY_SOURCE=2 -fexceptions -fstack-protector-strong --param=ssp-buffer-size=4 -grecord-gcc-switches -specs=/usr/lib/rpm/redhat/redhat-hardened-cc1 -m64 -mtune=generic' --with-ld-opt='-Wl,-z,relro -specs=/usr/lib/rpm/redhat/redhat-hardened-ld -Wl,-E' && make modules

RUN echo -e 'load_module modules/ngx_http_statsd_module.so;' >statsd.conf

RUN fpm -s dir -t rpm --name nginx-mod-http-statsd --version $(nginx -v 2>&1 | sed 's|.*/||g') --iteration $(date +%s) nginx-$(nginx -v 2>&1 | sed 's|.*/||g')/objs/ngx_http_statsd_module.so=/usr/share/nginx/modules/ statsd.conf=/usr/share/nginx/modules/

RUN yum localinstall -y *.rpm

RUN nginx -T

RUN mkdir /target && cp *.rpm /target/ && chmod -R a+r /target && chmod a+x /target

CMD nginx && tail -f /var/log/nginx/*.log & bash
