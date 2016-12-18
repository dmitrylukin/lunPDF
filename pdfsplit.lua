-------------------------------------
--@author dimitry.lukin@gmail.com

debug = true

local function testUnnecessary(tab, element, list)
    for i,v in pairs(list) do
        if tonumber(v) == tonumber(element) then
            return true
        end
    end
    return false
end

local function copyTable(original)
    local copy = {}
    for k, v in pairs(original) do
           if type(v) == 'table' then
                v = copyTable(v)
           end
           copy[k] = v
    end
    return copy
 end

PdfFile = {}

PdfFile.Trailer = nil
PdfFile.NumPages = nil
PdfFile.Structure = {}
PdfFile.Offset = {}
PdfFile.Stream = {}
PdfFile.ObjectCounter = 0
PdfFile.RootObject = 0
PdfFile.PagesObject = 0
PdfFile.PagesKids = {}
PdfFile.Resources = {}
PdfFile.ImagesObjects = {}


PdfFile.Read = function(filename)
    local fh = assert(io.input(filename))
    return fh
end

PdfFile.Parse = function(fh)
    local structure = {}
    while true do
        local line = io.read()
        if line == nil or line == "%%EOF" then break end
        local n, sn = line:match("(%d+)%s+(%d+)%s+obj")
        if n then
            local isObject = true
            PdfFile.ObjectCounter = PdfFile.ObjectCounter + 1
            n = tonumber(n)
            structure[n] = ""
--            if debug then print("Found Object "..n) end
            while isObject do
                line = io.read()
                if line == nil then break end
                if not line:match("endobj") then
                     if line:match("^stream") then
                        local StartStreamPos = io.input():seek()
                        while true do
                            if io.read():match("endstream")  then break end
                        end
                        local StopStreamPos = io.input():seek() - 9
                        local binfh = io.open(arg[1], "rb")
                        binfh:seek("set", StartStreamPos)
                        PdfFile.Stream[n] = binfh:read(StopStreamPos - StartStreamPos - 1)
                        binfh:close()
                      end
                    structure[n] = structure[n]..line.."\n"
                else
                    isObject = false
                end
            end
--            if debug then print(structure[n]) end
        end -- end if obj found
        if line:match("trailer") then
        trailer = ""
            while true do
                line = io.read()
                trsubst = {"(/Size%s%d+)", "(/Root%s+%d+%s+%d+%s+R)", "(/Info%s+%d+%s+%d+%s+R)", }
                for _, i in pairs(trsubst) do
                    
                    local trout = line:match(i) or ""
                    if trout ~= "" then trout = trout.."\n" end
                    trailer = trailer..trout
                end
                if line:match(">>") then
                    break
                end
            end
        end 
    end -- main loop

    return trailer, structure
end 

fh = PdfFile.Read(arg[1])
PdfFile.Trailer, PdfFile.Structure = PdfFile.Parse(fh)

-- if debug then print("Trailer: "..PdfFile.Trailer) end
-----------------------
-- Get root catalog
PdfFile.RootObject = PdfFile.Trailer:match("/Root%s+(%d+)%s+%d+")
if debug then print("RootCatalog object:  "..PdfFile.RootObject) end
-----------------------
-- Get page number
PdfFile.RootObject = tonumber(PdfFile.RootObject)
PdfFile.PagesObject = PdfFile.Structure[PdfFile.RootObject]:match("/Pages%s(%d+)%s%d%sR")
if debug then print("Pages object:  "..PdfFile.PagesObject) end
PdfFile.PagesObject = tonumber(PdfFile.PagesObject)
PdfFile.NumPages = PdfFile.Structure[PdfFile.PagesObject]:match("/Count%s(%d+)")
if debug then print("Number of pages in pdf: "..PdfFile.NumPages) end

PdfFile.NumPages = tonumber(PdfFile.NumPages)
if PdfFile.NumPages == 1 then 
    print("There is one page pdf document. No changes needed.") 
    return 0
end
---------------------------
-- Create output files
for pageCounter = 1, PdfFile.NumPages do
    -- create filename 
    local fname = arg[1]:match("(%a+).pdf")
    fname = fname.."-"..pageCounter..".pdf"
    local wfh=io.open(fname,"wb")
---------------------------------------
-- Creating output PdfFile
    
    local PdfFile2Write = copyTable(PdfFile)
-- Write /Count 1 to Pages obj
    local a = PdfFile.Structure[PdfFile.PagesObject]:gsub("/Count%s+%d+", "/Count 1")
    PdfFile2Write.Structure[PdfFile2Write.PagesObject] = a
-- 
    local tmp = PdfFile2Write.Structure[PdfFile2Write.PagesObject]:gsub("\n","")
    local b = tmp:match("/Kids%s*%[(.+)%]") -- b ia a list of Kids in form "12 0 R 2 0 R 7 0 R"  and so
    local kids = b
    for k = 1, pageCounter - 1 do 
        b = b:gsub("^%s*%d+%s+%d+%s+%a+", " ", 1) -- b is a 
    end
    PdfFile.PagesKids[pageCounter] = b:match("^%s*(%d+)%s+0%s+R")      
-- 
    z = tmp:gsub("/Kids%s*%[(.+)%]", "/Kids[ "..PdfFile.PagesKids[pageCounter].." 0 R ]")
    PdfFile2Write.Structure[PdfFile2Write.PagesObject] = z
--------------------------------------
-- Try to remove unused objects
    unnecessaryList = {}
    while true do
        key, tail = kids:match("^%s*(%w+)%s+(.*)$")
        if not key then break end
        if not ( key == "0" or key == "R" or tonumber(key) == tonumber(PdfFile.PagesKids[pageCounter]) ) then
            local tmp = PdfFile2Write.Structure[tonumber(key)]:gsub("\n", " ")
            local page = tmp:match("/Resources%s+(%d+)%s+%d+%s+R")
            local imgPage = PdfFile2Write.Structure[tonumber(page)]:gsub("\n", " ")
            local imgObj = imgPage:match("/Im0%s+(%d+)%s+%d+%s+R")
            table.insert(unnecessaryList, imgObj)
        end
        kids = tail
    end
--    removeUnnecessary(PdfFile2Write, unnecessaryList)
---------------------------------------
-- Forming page
    -- write header
    wfh:write("%PDF-1.3\n")
    wfh:write("%\208\206\165\178\n")
    -- write objects
    for i,data in pairs(PdfFile2Write.Structure) do
        if not testUnnecessary(PdfFile2Write, i, unnecessaryList) then 
print("obj number  "..i)
            PdfFile2Write.Offset[i] = wfh:seek()
            wfh:write(i.." 0 obj\n")    
            wfh:write(PdfFile2Write.Structure[i])
            if PdfFile2Write.Stream[i] ~=nil then 
                wfh:seek("end")
                wfh:write(PdfFile2Write.Stream[i])
                wfh:write("endstream\n")
            end
            wfh:write("endobj\n\n")
        end -- end if test unnecessaty
    end
   -- write trailer
    local xferOffset = wfh:seek()
    wfh:write("xref\n")
    wfh:write("0 "..tostring(PdfFile2Write.ObjectCounter + 1).."\n")
    wfh:write("0000000000 65535 f\n")
    for i in pairs(PdfFile2Write.Structure) do
        if not testUnnecessary(PdfFile2Write, i, unnecessaryList) then 
            o = string.format("%010d", PdfFile2Write.Offset[i])
            wfh:write(o.." 00000 n\n")
        end
    end
    wfh:write("trailer\n<<\n")
    wfh:write(PdfFile2Write.Trailer..">>\n")
    -- write footer 
    wfh:write("startxref\n"..xferOffset.."\n")
    wfh:write("%%EOF\n")
    wfh:close()
end -- end write file loop


