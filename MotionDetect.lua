
-- MotionDetect V1.02 20170321 增加部分实验代码, 用 CPU 计算矩形坐标, 用 shader 画矩形框
-- GrabMotion
-- 写成库的形式

function setup()
    
    mo = Motion
    -- 初始化，分配图像，设置初始参数值
    mo.init()
end

function draw()
    
    background(40, 40, 50)
    
    -- 启动检测 starting detect
    mo.detect()
    
    -- 根据检测结果为有动作变化的位置加矩形框 add rect on the motion area
    mo.addRect()
end


-- 实时动作检测库
Motion = {}

local mo = Motion

function Motion.init()
    displayMode(OVERLAY)
    spriteMode(CORNER)
    memory = 0
    -- 用来调节判读颜色差值 adjust the sub of two colors
    parameter.number("deltaColor",0,0.5,0.2)
    -- parameter.number("dScaler",2,20,10)
    parameter.watch("memory")
    parameter.watch("1/DeltaTime")
    parameter.watch("ElapsedTime")
    parameter.watch("os.clock()")
    
    -- parameter.watch("period1")
    cameraSource(CAMERA_FRONT)
    -- cameraSource(CAMERA_BACK)
    
    img = image(CAMERA)
    print(img)
    
    -- 设置矩形框判断处理中的一些参数 set some parameter in the rect function
    scaler = 10
    threshold = 5
    
    -- 用于保存动作区域坐标 keep the coordinate of the motion area
    cdx,cdy = {},{}
    
    -- 创建 mesh，准备使用 GPU create mesh, prepare using GPU to do the detect job
    m = mesh()
    mp = mesh()
    ma = mesh()
    
    tex = image(WIDTH,HEIGHT)
    period1 = ElapsedTime
    -- period1 = os.clock()
    
    -- 下一帧到当前帧的时间间隔
    delayNextFrame = 10/60
    
    -- 下一帧比当前帧延迟 delayNextFrame
    period2 = period1 + delayNextFrame
    
    img0 = image(WIDTH/1,HEIGHT/1)
    img1 = image(WIDTH/1,HEIGHT/1)
    img2 = image(WIDTH/1,HEIGHT/1)
    img3 = image(WIDTH/1,HEIGHT/1)
    img4 = image(WIDTH/scaler,HEIGHT/scaler)
    img5 = image(WIDTH/1,HEIGHT/1)
    
    local w,h = img1.width, img1.height
    
    -- 用于检测动作 detect motion
    m:addRect(WIDTH/2,HEIGHT/2,WIDTH/1,HEIGHT/1)
    m.shader = shader(myShader.vs,myShader.fs)
    -- m.texture = img1
    m.shader.tex0 = img0
    m.shader.tex1 = img1
    m.shader.tex2 = img2
    
    -- 用于为动作位置增加矩形框 add rect to show where it action
    ma:addRect(WIDTH/2,HEIGHT/2,WIDTH/1,HEIGHT/1)
    ma.shader = shader(myShader.vs,myShader.fs1)
    ma.shader.resolution = vec2(WIDTH,HEIGHT)
    ma.shader.tex0 = img3
    
    -- 用于其他处理
    mp:addRect(WIDTH/2+200,HEIGHT/2,WIDTH/3,HEIGHT/3)
    mp.texture = img2
end

function Motion:detect()
    pushStyle()
    spriteMode(CORNER)
    
    -- 计算实时内存状态
    memory = string.format("%.3f Mb",collectgarbage("count")/1024)
    
    -- 动态设置颜色阈值
    m.shader.deltaColor = deltaColor
    
    -- 视频流全速率绘制到 img0
    setContext(img0)
    sprite(CAMERA,0,0,WIDTH,HEIGHT)
    setContext()
    
    -- 每一轮 draw 的当前时间和 DeltaTime
    -- currentT = os.clock()
    currentT = ElapsedTime
    
    -- 每个 draw 中的取样频率，也可跨越单个 draw 周期，比如 2 秒
    local dTPerDraw = DeltaTime
    
    -- 当前选择帧，作为对比基准帧，注意：本帧每隔 dTPerDraw 重新从视频流中取样获得
    if currentT - period1 > dTPerDraw  then
        period1 = currentT
        setContext(img1)
        -- sprite(CAMERA,WIDTH/2,HEIGHT/2,WIDTH,HEIGHT)
        sprite(CAMERA,0,0,WIDTH,HEIGHT)
        -- print("p1: ",period1)
        setContext()
    end
    
    -- 用于跟当前选择帧做对比的下一帧
    if currentT - period2  > dTPerDraw  then
        period2 = currentT + delayNextFrame
        setContext(img2)
        -- sprite(CAMERA,WIDTH/2,HEIGHT/2,WIDTH,HEIGHT)
        sprite(CAMERA,0,0,WIDTH,HEIGHT)
        -- print("p2: ",period2)
        setContext()
        -- cdx,cdy = {},{}
    end
    
    -- 通过执行 m:draw 来让 shader 处理前后帧对比，并把处理结果绘制到 img3
    setContext(img3)
    m:draw()
    setContext()
    
    -- 绘制带有动作检测标示色的原图 img3
    sprite(img3,0,0,WIDTH,HEIGHT)
    
    -- 绘制原始视频流
    sprite(CAMERA,0,0,WIDTH,HEIGHT)
    popStyle()
end

function Motion:addRect()

    
    -- 以下在 Codea 中用 CPU 为动作位置画框
    -- 在缓冲区 img4 中把原图缩小(为节省计算)，检查有变动的部分
    local sw,sh = WIDTH/scaler,HEIGHT/scaler
    setContext(img4)
    pushMatrix()
    sprite(img3,0,0,sw,sh)
    popMatrix()
    setContext()
    
    --[[ 再放大: 配合第二种画框算法使用
    setContext(img5)
    pushMatrix()
    sprite(img4,0,0,WIDTH,HEIGHT)
    popMatrix()
    setContext()
    
    -- 再缩小，可过滤掉一部分有变化但变化不大的区域
    setContext(img4)
    pushMatrix()
    sprite(img5,0,0,sw,sh)
    popMatrix()
    setContext()
    --]]
    
    -- 在右上角显示缩小的图
    sprite(img4,WIDTH-sw-5,HEIGHT-sh-5,sw,sh)
    
    ---[[ 在缩小的图中检查是否有动作标示色，若有则语音提示，同时画矩形框
    local w,h = img4.width,img4.height
    local k= 0
    -- 为节省计算，可调节步长
    local sx,sy = 2,2
    for x= 1,w,sx do
        for y = 1,h,sy do
            -- 取得当前像素点的颜色
            local r,g,b,a =img4:get(x,y)
            ---[==[ 扫描图像中所有像素
            if (r==255 and g == 255 and b == 0) then
                k = k + 1
                if k > threshold then
                    table.insert(cdx,x)
                    table.insert(cdy,y)
                    speech.say("act")
                    speech.stop()
                    k=0
                end
            end
            --]==]
            --[=[ 另一种判断思路，向右，向上递增坐标
            if (r==255 and g == 255 and b == 0) then
                table.insert(cdx,x)
                table.insert(cdy,y)
                k = 0
                p=true
                while (p and k<threshold and x+k<w and y+k<h) do
                    local rr,rg,rb,ra =img4:get(x+k,y)
                    local tr,tg,tb,ta =img4:get(x,y+k)
                    if ((rr==255 and rg == 255) or (tr==255 and tg == 255)) then 
                        --speech.say("act")
                        --speech.stop()
                        k=k+10
                    else 
                        table.insert(cdx,x+k)
                        table.insert(cdy,y+k)
                        k=1; p=false 
                        break
                    end
                end
            end
            --]=]
        end
    end
    
    -- 对表排序，取出 cdx,cdy 表中第一项和最后一项，分别代表最左，最右，最下，最上
    if #cdx ~= 0 and #cdy ~= 0 then
        pushStyle()
        -- print("#cdx,cdx[1]: ",#cdx,cdx[1])
        -- print("#cdy,cdy[1]: ",#cdy,cdy[1])
        -- local cx,cy =
        print(#cdx)
        table.sort(cdx)
        table.sort(cdy)
        -- print(cx,#cx)
        -- 构造左下角，右上角的坐标
        local lb,rt= vec2(cdx[1],cdy[1]),vec2(cdx[#cdx],cdy[#cdy])
        -- 复原为大图
        lb,rt=lb*scaler,rt*scaler
        -- print(lb,rt)
        -- fill(10, 255, 0, 255)
        noFill()
        stroke(0, 221, 255, 255)
        strokeWidth(5)
        -- rectMode(CENTER)
        -- 计算矩形的左下角坐标以及宽高
        local x,y,w,h = lb.x,lb.y,rt.x-lb.x,rt.y-lb.y
        ma.shader.lb, ma.shader.rt = lb/WIDTH,rt/HEIGHT
        rect(x,y,w,h)
        
        --[==[ 也可以使用 ma 中的 shader 对动作位置画框，算法还不成熟，暂时注释
        ma.shader.tex0 = img3
        ma.shader.tex1 = img0
        ma:draw()
        --]==]
    
        tint(255,255,255,180)
        sprite("Tyrian Remastered:Flame 1",x,y,w,h)
        -- 已完成当前矩形框绘制，把 cdx,cdy 表中坐标清空
        cdx,cdy = {},{}
        popStyle()
    end
    --]]
    

end

myShader = {
vs =[[
uniform mat4 modelViewProjection;

//This is the current mesh vertex position, color and tex coord
// Set automatically
attribute vec4 position;
attribute vec4 color;
attribute vec2 texCoord;

//This is an output variable that will be passed to the fragment shader
varying lowp vec4 vColor;
varying highp vec2 vTexCoord;

void main()
{
gl_Position = modelViewProjection * position;

vColor = color;
vTexCoord = texCoord;
}
]],

-- 用于对比前后帧变化的 shader
fs =[[
uniform highp sampler2D tex0;
uniform highp sampler2D tex1;
uniform highp sampler2D tex2;

uniform highp float deltaColor;

//The interpolated vertex color for this fragment
varying lowp vec4 vColor;

//The interpolated texture coordinate for this fragment
varying highp vec2 vTexCoord;

uniform highp float time;

highp float grey(lowp vec4 col)
{
highp float grey = 0.2126*col.r + 0.7152* col.g + 0.0722*col.b;
return grey;
}

void main()
{
highp vec2 uv = vTexCoord;

highp vec4 col,col0,col1,col2;

col0 = texture2D(tex0,uv);
col1 = texture2D(tex1,uv);
col2 = texture2D(tex2,uv);

// 计算前后帧相同坐标处颜色的差值，判断其是否有变化
highp vec4 dCol;
highp float g;

dCol = abs(col1-col2);

g = grey(dCol);

if (g <= deltaColor) { col = col0;
// 设为黑色，直接输出二值图像
//col = vec4(0.,0.,0.,1.);
} else {
col = vec4(1.,1.,0.0,1.);
}

gl_FragColor = col;
}
]],

-- 用于在动作位置画框的 shader
fs1 =[[

varying highp vec2 vTexCoord;

highp vec4 col,col0,col1,col2;

uniform highp sampler2D tex0;
uniform highp sampler2D tex1;
uniform highp vec2 resolution;

uniform highp vec2 lb;
uniform highp vec2 rt;

void main() {
highp vec2 uv = vTexCoord;

// 从带有动作标示色的图像中取样
col0 = texture2D(tex0,uv);
col1 = texture2D(tex1,uv);

/*
// 新坐标
highp vec2 dl,dr,db,dt;

// 若取样点为动作区域
if (col0.r ==1. && col0.g == 1. && col0.b == 0.) {
// 相邻像素的距离
highp vec2 step = vec2(1.,1.)/resolution.xy;
// 判断条件
bool p =true;
highp float k = 1.;

//highp float minX,minY,maxX,maxY=uv.x,uv.y,uv.x,uv.y;

while (p && k <1000.) {
//if (k < 2000.) {

// 上下左右像素的坐标
dl = uv-vec2(step.x,0.)*k;
dr = uv+vec2(step.x,0.)*k;
db = uv-vec2(0.,step.y)*k;
dt = uv+vec2(0.,step.y)*k;

// 在 uv 四周取样，左右上下像素的颜色
highp vec4 l,r,b,t;
l = texture2D(tex0,dl);
r = texture2D(tex0,dr);
b = texture2D(tex0,db);
t = texture2D(tex0,dt);

//minX,minY,maxX,maxY=min(dl.x,minX),min(db.y,miny),max(dr.x,maxX),max(dt.y,maxY);

// 若任一点为标示色，则继续扩大一圈取样，若都不为标示色则退出循环，当前坐标即为矩形框坐标范围
if ((l.r == 1. && l.g ==1.) || (r.r == 1. && r.g ==1.) || (b.r == 1. && b.g ==1.) || (t.r == 1. && t.g ==1.)){
// 扩大坐标范围，继续搜索周围像素
k = k+1.;

} else {k = 1.; p = false;}

}

} else {col = col0;}

// 绘制框
highp float d=.1;

// 在 shader 中计算矩形框的坐标
gl_FragColor = col1;
//if ((uv.x>=dl.x && uv.x <= dr.x) && (uv.y>=db.y && uv.y <= dt.y)) {gl_FragColor = vec4(1.,0.,0.,1.);}
//if ((uv.x>=dl.x+d && uv.x <= dr.x-d) && (uv.y>=db.y+d && uv.y <= dt.y-d)) {gl_FragColor = col0;}

// 先绘制一个位置固定的矩形框
//if ((uv.x>=.1 && uv.x <= .5) && (uv.y>=.4 && uv.y <= .8)) {col = vec4(1.,0.,0.,1.);}
//if ((uv.x>=.1+d && uv.x <= .5-d) && (uv.y>=.4+d && uv.y <= .8-d)) {col = col0;}
*/

highp float d=.01;
// 由 CPU 提供矩形框坐标
gl_FragColor = col1;
if ((uv.x>=lb.x && uv.x <= rt.x-lb.x) && (uv.y>=lb.y && uv.y <= rt.y-lb.y)) {gl_FragColor = vec4(1.,1.,0.,.6);}
if ((uv.x>=lb.x+d && uv.x <= rt.x-lb.x-d) && (uv.y>=lb.y+d && uv.y <= rt.y-lb.y -d)) {gl_FragColor = col1;}


//gl_FragColor = col;
}

]]
}
