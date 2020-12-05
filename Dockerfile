FROM node:12-alpine
RUN find / -name build_and_run.sh
ADD docker-hexo/ /
RUN echo "Asia/Shanghai" > /etc/timezone \
    && npm install hexo-cli -g \
    && chmod 777 /docker-hexo/build_and_run.sh
EXPOSE 80

ENTRYPOINT ["sh","/docker-hexo/build_and_run.sh"]