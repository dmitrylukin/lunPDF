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

local function toString(tab)
    local str = ""
    if type(tab) ~= 'table' then 
        return tab
    end
    for k, v in pairs(tab) do
           if type(v) == 'table' then
                v = toString(v)
           end
           str = str..v
    end
    return str
 end


local function getNextBinaryChar(stream, pos) 
    return stream:sub(pos, pos)
end

local function getItNum(tab, regexp)
    if type(tab) ~= 'table' then     return tonumber(tab:match(regexp))     end
    for _, v in pairs(tab) do
        res = v:match(regexp)
        if res then return tonumber(res) end
    end
    return nil
end
local function changeItString(tab, from, to)
    local tmp = ""
    if type(tab) ~= 'table' then tmp = tab:gsub(from, to) 
    else
        for _, v in pairs(tab) do 
            tmp = tmp..v:gsub(from, to)
        end
    end
    return tmp:gsub("\n","")
end

PdfFile = {}

PdfFile.Trailer = nil
PdfFile.NumPages = nil
PdfFile.ObjectCounter = 0
PdfFile.RootObject = 0
PdfFile.PagesObject = 0
PdfFile.Structure = {}
PdfFile.Offset = {}
--PdfFile.Stream = {}
PdfFile.PagesKids = {}
PdfFile.Resources = {}



PdfFile.Parse = function(blob)
    local temporaryTable = {}
    local structure = {}
-------------------------------------------
-- Fill temporary table with blob content
    local currentLine = 1
    temporaryTable[currentLine] = ""
    for currentChar = 1, #blob do
        char = getNextBinaryChar(blob, currentChar)
        temporaryTable[currentLine] = temporaryTable[currentLine]..char
        if char == "\n" then
            currentLine = currentLine + 1
            temporaryTable[currentLine] = ""
        end
    end


    if debug then print("Number of lines in temporary table: "..table.getn(temporaryTable)) end
    for currentLine = 1, table.getn(temporaryTable) do
        if temporaryTable[currentLine]:match("%%EOF") then 
            if debug then print("Got EOF :"..temporaryTable[currentLine]) end
            break 
        end
        local n, sn = temporaryTable[currentLine]:match("(%d+)%s+(%d+)%s+obj")
        if n then
            currentLine = currentLine + 1
            local isObject = true
            PdfFile.ObjectCounter = PdfFile.ObjectCounter + 1
            if debug then print("Found Object "..n) end
            n = tonumber(n)
            structure[n] = ""
            while isObject do
                if not temporaryTable[currentLine]:match("endobj") then
--                    if temporaryTable[currentLine]:match("stream") then
--                        if debug then print("Object with a stream") end
--                        PdfFile.Stream[n] = ""
--                        while true do
--                           PdfFile.Stream[n] = PdfFile.Stream[n]..temporaryTable[currentLine]
--                            currentLine = currentLine + 1
--                            if temporaryTable[currentLine]:match("^endstream") then
--                                PdfFile.Stream[n] =PdfFile.Stream[n].."endstream\n"
--                                currentLine = currentLine + 1
--                                break
--                            end
--                        end
--                     end -- if match straem
                     structure[n] = structure[n]..temporaryTable[currentLine]
                else
                    isObject = false
                end -- end if endobj
            currentLine = currentLine + 1
            end -- end while isObject

--            if debug then print("Object text: ", unpack(structure)) end
        end -- end if obj found
--print(structure[5])
        if temporaryTable[currentLine]:match("trailer") then
        trailer = ""
            while true do
                local tline = temporaryTable[currentLine]:gsub("\n","")
                trsubst = {"(/Size%s%d+)", "(/Root%s+%d+%s+%d+%s+R)", "(/Info%s+%d+%s+%d+%s+R)", }
                for _, i in pairs(trsubst) do
                    
                    local trout = temporaryTable[currentLine]:match(i) or ""
                    if trout ~= "" then trout = trout.."\n" end
                    trailer = trailer..trout
                end
                if temporaryTable[currentLine]:match(">>") then
                    break
                end
            currentLine = currentLine + 1
            end
        end 
    end -- main loop

    return trailer, structure
end 


function split(pdf) 

    if debug then print("Blob size: "..#pdf.." bytes") end
    PdfFile.Trailer, PdfFile.Structure = PdfFile.Parse(pdf)
-- if debug then print("Trailer: "..PdfFile.Trailer) end
-----------------------
-- Get root catalog
    PdfFile.RootObject = tonumber(PdfFile.Trailer:match("/Root%s+(%d+)%s+%d+"))
    if debug then print("RootCatalog object:  "..PdfFile.RootObject) end
-----------------------
-- Get root page number
    PdfFile.PagesObject = getItNum(PdfFile.Structure[PdfFile.RootObject],"/Pages%s(%d+)%s%d%sR")
    if debug then print("Pages object:  "..PdfFile.PagesObject) end
    PdfFile.NumPages = PdfFile.Structure[PdfFile.PagesObject]:match("/Count%s(%d+)")
    if debug then print("Number of pages in pdf: "..PdfFile.NumPages) end

    PdfFile.NumPages = tonumber(PdfFile.NumPages)
    if PdfFile.NumPages == 1 then 
        print("There is one page pdf document. No changes needed.") 
        return 0
    end
---------------------------
-- Create output blobs
    local outputBlob = {}
    for pageCounter = 1, PdfFile.NumPages do
        local outputBlobIDX = pageCounter
---------------------------------------
-- Creating output PdfFile
    
    local PdfFile2Write = copyTable(PdfFile)
-- Write /Count 1 to Pages obj
    local a = changeItString(PdfFile.Structure[PdfFile.PagesObject], "/Count%s+%d+", "/Count 1")
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
        if not ( key == "0" or key == "R" or tonumber(key) == tonumber(PdfFile.PagesKids[pageCounter]) ) then -- Find valuable numbers
        local tmp = changeItString(PdfFile2Write.Structure[tonumber(key)],"\n","")
            local page = tmp:match("/Resources%s+(%d+)%s+%d+%s+R")
            local imgPage = PdfFile2Write.Structure[tonumber(page)]:gsub("\n", " ")
            local imgObj = imgPage:match("/Im0%s+(%d+)%s+%d+%s+R")
            table.insert(unnecessaryList, imgObj)
        end
        kids = tail
    end
--    removeUnnecessary(PdfFile2Write, unnecessaryList)
---------------------------------------
-- Forming output pdf page
    outputBlob[outputBlobIDX] = ""
    -- write header
    
    outputBlob[outputBlobIDX] = outputBlob[outputBlobIDX].."%PDF-1.3\n"
    outputBlob[outputBlobIDX] = outputBlob[outputBlobIDX].."%\208\206\165\178\n"
    -- write objects
    for i,data in pairs(PdfFile2Write.Structure) do
        if not testUnnecessary(PdfFile2Write, i, unnecessaryList) then 
            PdfFile2Write.Offset[i] = #outputBlob[outputBlobIDX]
            outputBlob[outputBlobIDX] = outputBlob[outputBlobIDX]..i.." 0 obj\n"    
            outputBlob[outputBlobIDX] = outputBlob[outputBlobIDX]..toString(PdfFile2Write.Structure[i])
--            if PdfFile2Write.Stream[i] ~=nil then 
--                outputBlob[outputBlobIDX] = outputBlob[outputBlobIDX]..toString(PdfFile2Write.Stream[i])
--            end
            outputBlob[outputBlobIDX] = outputBlob[outputBlobIDX].."endobj\n"
        end -- end if test unnecessaty
    end -- for loop
   -- write trailer
    local xferOffset = #outputBlob[outputBlobIDX]
    outputBlob[outputBlobIDX] = outputBlob[outputBlobIDX].."xref\n"
    outputBlob[outputBlobIDX] = outputBlob[outputBlobIDX],"0 "..tostring(PdfFile2Write.ObjectCounter + 1).."\n"
    outputBlob[outputBlobIDX] = outputBlob[outputBlobIDX].."0000000000 65535 f\n"
    for i in pairs(PdfFile2Write.Structure) do
        if not testUnnecessary(PdfFile2Write, i, unnecessaryList) then 
            o = string.format("%010d", PdfFile2Write.Offset[i])
            outputBlob[outputBlobIDX] = outputBlob[outputBlobIDX]..o.." 00000 n\n"
        end
    end
    outputBlob[outputBlobIDX] = outputBlob[outputBlobIDX].."trailer\n<<\n"
    outputBlob[outputBlobIDX] = outputBlob[outputBlobIDX]..toString(PdfFile2Write.Trailer)..">>\n"
    -- write footer 
    outputBlob[outputBlobIDX] = outputBlob[outputBlobIDX].."startxref\n"..xferOffset.."\n"
    outputBlob[outputBlobIDX] = outputBlob[outputBlobIDX].."%%EOF\n"
end -- end write file loop

return outputBlob


end -- end split (main) function

--------------------------------------------------
-- Cut below

local a = io.open("rep.pdf",rb)
local f = a:read("*all")
io.close(a)



local o = split(f)

for i =1, table.getn(o) do
local str = toString(o[i])
local w = io.output("rep-"..i..".pdf")
io.write(str)
io.close(w)
end
