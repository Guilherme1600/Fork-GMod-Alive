if SERVER then return end
local GA=GModAlive
GA.UI={bg=Color(226,201,147),surface=Color(209,190,143),input=Color(240,221,176),text=Color(65,48,28),muted=Color(112,91,57),accent=Color(130,97,43),bad=Color(155,52,38),line=Color(137,113,67)}
local C=GA.UI
surface.CreateFont("GA.RPG.Title",{font="Georgia",size=23,weight=600,extended=true})
surface.CreateFont("GA.RPG.Body",{font="Roboto",size=17,weight=500,extended=true})
surface.CreateFont("GA.RPG.Small",{font="Roboto",size=13,weight=600,extended=true})
function C.Frame(panel,title,subtitle)
    panel:SetTitle("")
    panel.Paint=function(_,w,h)
        surface.SetDrawColor(C.bg) surface.DrawRect(0,0,w,h)
        surface.SetDrawColor(Color(89,66,28)) surface.DrawRect(2,2,w-4,34)
        surface.SetDrawColor(Color(244,224,177,45))
        for i=1,32 do surface.DrawRect((i*137)%(w-10)+5,75+(i*79)%math.max(1,h-85),2,2) end
        surface.SetDrawColor(C.line) surface.DrawOutlinedRect(0,0,w,h,1) surface.DrawLine(18,70,w-18,70)
        draw.SimpleText(title,"GA.RPG.Title",12,7,Color(250,237,203))
        draw.SimpleText(subtitle or "GMOD ALIVE","GA.RPG.Small",23,48,C.text)
    end
    if IsValid(panel.btnClose) then
        panel.btnClose:SetText("") panel.btnClose.Paint=function(self,w,h)
            draw.SimpleText("×","GA.RPG.Body",w/2,h/2,self:IsHovered() and color_white or Color(235,218,175),TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
        end
    end
end
function C.Button(button,primary)
    button:SetFont("GA.RPG.Body") button:SetTextColor(primary and color_white or C.text)
    button.Paint=function(self,w,h)
        surface.SetDrawColor(primary and (self:IsHovered() and Color(156,122,64) or C.accent) or (self:IsHovered() and C.input or C.surface)) surface.DrawRect(0,0,w,h)
        surface.SetDrawColor(C.line) surface.DrawOutlinedRect(0,0,w,h,1)
    end
end
function C.Entry(input)
    input:SetFont("GA.RPG.Body") input:SetTextColor(C.text) input:SetCursorColor(C.accent)
    input.Paint=function(self,w,h)
        surface.SetDrawColor(C.input) surface.DrawRect(0,0,w,h)
        surface.SetDrawColor(self:HasFocus() and C.accent or C.line) surface.DrawOutlinedRect(0,0,w,h,1)
        self:DrawTextEntryText(C.text,C.accent,C.text)
        if self:GetValue()=="" and not self:HasFocus() then draw.SimpleText(self:GetPlaceholderText() or "","GA.RPG.Body",10,12,C.muted) end
    end
end
function C.Combo(combo)
    combo:SetTextColor(C.text) combo:SetFont("GA.RPG.Body")
    combo.Paint=function(_,w,h)
        surface.SetDrawColor(C.input) surface.DrawRect(0,0,w,h)
        surface.SetDrawColor(C.line) surface.DrawOutlinedRect(0,0,w,h,1)
    end
end
