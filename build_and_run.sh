# 把hexo框架clone到容器中
git clone https://github.com/com-wushuang/docker-hexo.git

# 将文章clone到容器中
git clone https://github.com/com-wushuang/blog.git
mv blog/source/_posts/* docker-hexo/source/_posts

cd docker-hexo/
npm install
hexo generate
hexo server -p 80