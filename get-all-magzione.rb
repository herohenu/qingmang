require 'rest-client'
require 'nokogiri'

class  Test 
#获取所有杂志栏目    
def start 
    urls  = []
    line_content_arr = []
    start_url = 'http://qingmang.me/magazines/'
    response = RestClient::Request.execute(method: :get, url: start_url, timeout: 500)
    resp_content = Nokogiri::HTML(response)
    current_magzines = resp_content.css("li.magazine")
    f  = File.open("magzines.txt"  ,"w+")
    current_magzines.map do |node|
        link = node.css('a').map { |link| link['href'] }
        h3text = node.css('a h3')[0].text 
        pcontent= node.css('a p').text  #[0].nil ?  "" : node.css('a p')[0].text
        background_image_node = node.css('a div')  #.map{|style| style['background-image']}
        background_image  =  background_image_node[0]['style'].to_s.split("(").last.to_s.split(")").first #.last.split(")" ).first#[/\((.*?)\)/m ,1  ]
        line_content_arr  = [link , h3text ,  pcontent , background_image ] 
        f.puts line_content_arr.join("\t")
        urls.push link
    end
    f.close 
    return urls.sort!
end


#request url  and return response
def request_url url 
     response = RestClient::Request.execute(method: :get, url: url, timeout: 500 , user_agent: "Mozilla/5.0 (Linux; U; Android 6.0.1; zh-CN; HUAWEI RIO-AL00 Build/HuaweiRIO-AL00) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/40.0.2214.89 UCBrowser/11.4.5.937 Mobile Safari/537.36" )
end

#读存储在文件中的
def  readFile( f ) 
    urls = { }
    begin
        File.readlines(f.to_s).each do |line| 
         line_arr  = line.split("\t") 
         if  line_arr.length > 3 
            url = "http://qingmang.me"  +  line_arr[0]
            urls.store url , line_arr[1..-1]
         end
         end
    rescue => exception
        puts "file  #{f}  not exists ,exexception :",  exception          
    end
    #puts urls.keys.sort!
    return urls.keys.sort!
end

#获取单个杂志的所有文章
def each_magazines  ( urls  )  
    #puts "urls is :" ,  urls
    urls.each do  |url  |
        #puts " this url is : "  , url 
        magzine_content  = [] 
        response = request_url   url 
        resp_content = Nokogiri::HTML(response)
        current_page_content  = resp_content.css("li.article-compact")
        magzine_content.concat( current_page_content )
        #puts " this  mag content is : \a "  , current_page_content 
        result = parse_content(   current_page_content , url   ) 
        
        blank_page = 0 
        #获取其他页的内容 todo 根据上一页下一页判断
        (1..50).to_a.each do  |page_index |
            if blank_page >= 1
                break
            end
            next_page  =  url + "?page=#{page_index}" 
            response = request_url   next_page 
            resp_content = Nokogiri::HTML(response)
            current_page_content = resp_content.css("li.article-compact") 
            if current_page_content.length == 0 
                blank_page += 1 
            else
                magzine_content.concat( current_page_content )
                result1 =  parse_content(current_page_content , url )
                result.merge! result1
            end
            #防止server 504 timeout 导致任务失败
            system("  sleep 0.35 ")
        end
        #break
    end
    system("  sleep 0.8")
end

#把文章索引解析出来
def parse_content   articles  , url  
    article_maps = {}
    magziname =  url[/magazines\/(.*)\//, 1].to_s  + ".txt"
    f = File.open(magziname  , "a+")
    articles.each do | node|
    begin 
        article_link =   node.css('a').map { |link| link['href'] }
        article_link = "http://qingmang.me" + article_link[0].to_s
        h3text = node.css('a h3')[0].text 
        pcontent= node.css("a p[class='lead']").text  #[0].nil ?  "" : node.css('a p')[0].text
        background_image_node = node.css('a div')  #.map{|style| style['background-image']}
        background_image  = ""
        if !(background_image_node.nil?  )  &&  background_image_node.to_s != ""
             background_image = background_image_node[0]['style'].to_s.split("(").last.to_s.split(")").first #.last.split(")" ).first#[/\((.*?)\)/m ,1  ]
        end
        p_meta_img_src = node.css("a p img").map{ |img| img['src']}
        p_meta_src = node.css("a p[class='meta']").text.to_s.gsub(/\s/, '')
        date_time = node.css("a time").map{|dt| dt['title']}
        line_content_arr  = [article_link , h3text ,pcontent  , background_image ,p_meta_img_src  , p_meta_src, date_time] 
       f.puts  line_content_arr.join("\t")
       article_maps.store( article_link ,  line_content_arr) 
     rescue Exception  =>e
             divobj = node.css('a div')
             puts " [#{magziname}]  fetch err #{e}"
     end
    end
    f.close
    return article_maps
end

 
 
end

#step1 启动任务获取所有的杂志列表 存储到magzines.txt  
t = Test.new 
#puts t.start 
#step2  获取每一本杂志对应的文章列表
urls = t.readFile "magzines.txt"
t.each_magazines(urls)
 
#step3 获取杂志索引
def interupt  urls , magazine_id
    idx =  Hash[urls.map.with_index.to_a]["http://qingmang.me/magazines/#{magazine_id}/"]
    puts idx 
    urls = urls[idx .. -1 ]
    puts urls , urls.length
end