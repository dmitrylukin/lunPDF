-------------------------------------
--@author dimitry.lukin@gmail.com

debug = true

PdfFile = {}

PdfFile.Trailer = nil
PdfFile.NumPages = nil
PdfFile.Structure = {}
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
            n = tonumber(n)
            structure[n] = ""
--            if debug then print("Found Object "..n) end
            while isObject do
                line = io.read()
                if line == nil then break end
                if not line:match("endobj") then
                    structure[n] = structure[n]..line
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
                trailer = trailer..line
                if line:match(">>") then
                    break
                end
            end
        end 
    end -- main loop

    return trailer, structure
end 

NullObject = {}
BooleanObject = {}
ArrayObject = {}
IndirectObject = {}
FloatObject = {}

NumberOblect = {}
    NumberOblect.regexp = "%d+"

fh = PdfFile.Read(arg[1])
PdfFile.Trailer, PdfFile.Structure = PdfFile.Parse(fh)

if debug then print("Trailer: "..PdfFile.Trailer) end
--
-- Get root catalog
local RootCatalog = PdfFile.Trailer:match("/Root%s+(%d+)%s+%d+")
if debug then print(RootCatalog) end

-- Get page number
RootCatalog = tonumber(RootCatalog)
Pages = PdfFile.Structure[RootCatalog]:match("/Pages%s(%d+)%s%d%sR")
if debug then print(Pages) end
Pages = tonumber(Pages)
PdfFile.NumPages = PdfFile.Structure[Pages]:match("/Count%s(%d+)")
if debug then print("Number of pages in pdf: "..PdfFile.NumPages) end
