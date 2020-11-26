# 将文章clone到容器中
git clone https://github.com/com-wushuang/blog.git
mv blog/* source/_posts
npm install
hexo generate
hexo server -p 80