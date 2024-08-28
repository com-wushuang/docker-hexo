git clone https://github.com/com-wushuang/docker-hexo.git
cd docker-hexo/
npm config set strict-ssl false
npm install
hexo generate
hexo server -p 80