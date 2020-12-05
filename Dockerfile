FROM node:12-alpine
ADD ./ /
RUN cat build_and_run.sh
RUN echo "Asia/Shanghai" > /etc/timezone \
    && npm install hexo-cli -g \
    && chmod 777 /build_and_run.sh
EXPOSE 80

ENTRYPOINT ["sh","/build_and_run.sh"]