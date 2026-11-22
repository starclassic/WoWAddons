from pathlib import Path
import sys
from lupa.lua51 import LuaRuntime

source = (Path(__file__).resolve().parents[1] / 'SCSeal' / 'SCSeal.lua').read_text()
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
frames, bindings, containers, messages, glowBindings, durationBindings = {}, {}, {}, {}, {}, {}
now, inCombat, auraID, ctrlDown = 10, false, 20375, false
nativeCallsInCombat, scansInCombat = 0, 0
SlashCmdList = {}
Enum = {SpellBookSpellBank={Player=0}}
CustomAuraContainerAuraProcessingPolicy = {None=0}
C_AuraContainerUtil = {}
local SECRET = {}
secretID = SECRET
function issecretvalue(v) return rawequal(v, SECRET) end
function issecrettable() return false end
function UnitClass() return 'Paladin', 'PALADIN' end
function InCombatLockdown() return inCombat end
function IsControlKeyDown() return ctrlDown end
function GetTime() return now end
function print(message) messages[#messages+1] = message end
local learned = {[20375]=true, [20154]=true, [20164]=true}
C_SpellBook = {IsSpellInSpellBook=function(id) return learned[id] or false end}
C_Spell = {GetSpellInfo=function(id)
    return {name=id==20375 and 'Seal of Command' or 'Seal of Righteousness', iconID=id+100}
end}
C_Secrets = {ShouldAurasBeSecret=function() return inCombat end}
C_UnitAuras = {GetAuraDataByIndex=function(_, index)
    if inCombat then scansInCombat=scansInCombat+1; error('secret combat aura read') end
    if index==1 and auraID then return {spellId=auraID} end
end}
local methods = {}
local function check(self)
    assert(not rawget(self, 'forbidden'), 'addon modified forbidden native frame')
end
setmetatable(methods, {__index=function(t,k)
    local fn=function(self, ...) check(self) end
    rawset(t,k,fn); return fn
end})
function methods:SetScript(name, fn) check(self); self.scripts[name]=fn end
function methods:GetFrameLevel() return rawget(self,'level') or 0 end
function methods:SetFrameLevel(v) check(self); self.level=v end
function methods:SetDurationCooldown(cd)
    check(self); durationBindings[#durationBindings+1]={button=self,cooldown=cd}
end
function methods:SetAlpha(a) check(self); self.alpha=a end
function methods:SetShown(v) check(self); self.shown=v end
function methods:SetPoint(p, parent, rp, x, y) check(self); self.point={p,parent,rp,x,y} end
function methods:GetPoint() return unpack(self.point or {'CENTER',UIParent,'CENTER',0,-140}) end
function methods:SetScale(v) check(self); self.scale=v end
function methods:EnableMouse(v) check(self); self.mouse=v end
function methods:SetText(v) check(self); self.text=v end
function methods:CreateFontString() check(self); return CreateFrame('FontString',nil,self) end
function methods:CreateTexture() check(self); return CreateFrame('Texture',nil,self) end
function methods:GetStatusBarTexture() return CreateFrame('Texture',nil,self) end
function methods:CreateAnimationGroup() return CreateFrame('AnimationGroup',nil,self) end
function methods:CreateAnimation() return CreateFrame('Animation',nil,self) end
function methods:SetApplicationBar(bar, opts)
    check(self)
    assert(opts.minApplications==2 and opts.maxApplications==3, 'incorrect glow threshold')
    glowBindings[#glowBindings+1]={button=self,bar=bar}
    bar.forbidden=true
end
function methods:SetEnabled(v)
    check(self)
    if self.kind=='AuraContainer' and inCombat then
        nativeCallsInCombat=nativeCallsInCombat+1; error('rebuild in combat')
    end
    self.enabled=v
end
function methods:AddAuraSlot(slot, _, opts)
    check(self)
    self.opts=opts; self.slot=slot
    local button=CreateFrame('NativeAuraButton',nil,self)
    opts.initializeFrame(button)
    button.forbidden=true
    self.button=button
end
function methods:SetApplicationCount(label, opts)
    check(self); bindings[#bindings+1]={button=self,label=label,formatter=opts.formatter}
    label.forbidden=true
end
function CreateFrame(kind, name, parent)
    local f=setmetatable({kind=kind,name=name,parent=parent,scripts={},alpha=1,shown=true}, {__index=methods})
    frames[#frames+1]=f
    if name then _G[name]=f end
    if kind=='AuraContainer' then containers[#containers+1]=f end
    return f
end
UIParent=CreateFrame('Frame','UIParent')
C_StringUtil={CreateNumericRuleFormatter=function()
    return {SetBreakpoints=function(self,b) self.breakpoints=b end}
end}
function event(name, a, b, c)
    for _,f in ipairs(frames) do
        if f.scripts.OnEvent then f.scripts.OnEvent(f,name,a,b,c) end
    end
end
function tick(seconds)
    now=now+seconds
    for _,f in ipairs(frames) do if f.scripts.OnUpdate then f.scripts.OnUpdate(f,seconds) end end
end
-- Emulate only the game's documented formatter selection, outside addon code.
function visible(frame)
    while frame do
        if rawget(frame,'alpha')==0 or rawget(frame,'shown')==false then return false end
        frame=rawget(frame,'parent')
    end
    return true
end
function rendered(echo, count, slot)
    for _,binding in ipairs(bindings) do
        local container=binding.button.parent
        if container.enabled and visible(container) and container.slot==(slot or 'Echo') and container.opts.candidateFilters.includeSpellIDs[echo] then
            local text=''
            for _,b in ipairs(binding.formatter.breakpoints) do
                if count>=b.threshold then text=b.format end
            end
            return text
        end
    end
    return ''
end
''')
lua.execute(source)
lua.execute(r'''
event('PLAYER_LOGIN')
assert(#containers==5)
assert(#glowBindings==2, 'both seals need a native three-stack glow')
assert(#durationBindings==1, 'native current-seal duration not bound')
local durationContainer=durationBindings[1].button.parent
assert(durationContainer.opts.candidateFilters.includeSpellIDs[20375])
assert(durationContainer.opts.candidateFilters.includeSpellIDs[20154])
assert(rendered(1311703,0,'Count')=='')
for n=1,3 do assert(rendered(1311703,n,'Count')==tostring(n), 'wrong active Echo count') end
assert(rendered(1311704,3,'Count')=='', 'inactive count visible')
for n=0,2 do assert(rendered(1311703,n)=='', 'premature prompt') end
assert(rendered(1311703,3)=='|T20254:64:64|t\n|cffffd45cSwitch|r', 'unexpected prompt text')
assert(rendered(1311704,3)=='', 'inactive seal shown')
inCombat=true
event('PLAYER_REGEN_DISABLED')
event('UNIT_SPELLCAST_SUCCEEDED','player','cast',20424)
assert(rendered(1311703,3):find('|T20254:',1,true), 'damage proc changed active seal')
event('UNIT_SPELLCAST_SUCCEEDED','player','cast',secretID)
assert(rendered(1311703,3):find('|T20254:',1,true), 'secret spell ID used')
event('UNIT_SPELLCAST_SUCCEEDED','player','cast',20154)
assert(rendered(1311703,3)=='', 'old pending stacks still suggest a seal')
assert(rendered(1311703,3,'Count')=='', 'pending previous-seal count leaked')
for n=1,3 do assert(rendered(1311704,n,'Count')==tostring(n), 'new seal count not followed') end
assert(#durationBindings==1 and durationBindings[1].button.parent==durationContainer,
    'switch suggestion replaced active-seal timer binding')
assert(rendered(1311704,3)=='|T20475:64:64|t\n|cffffd45cSwitch|r', 'unexpected reverse prompt text')
event('UNIT_SPELLCAST_SUCCEEDED','player','cast',20164)
assert(rendered(1311704,3)=='', 'other seal did not dismiss prompt')
event('SPELLS_CHANGED')
assert(#containers==5, 'rebuilt native frames in combat')
tick(1)
assert(scansInCombat==0 and nativeCallsInCombat==0)
inCombat=false; auraID=20375
event('PLAYER_REGEN_ENABLED')
assert(#containers==10, 'deferred rebuild missing')
SlashCmdList.SCSEAL('test')
assert(rendered(1311703,3)=='', 'live prompt visible over preview')
assert(SCSealDB.preview)
inCombat=true; event('PLAYER_REGEN_DISABLED')
assert(not SCSealDB.preview and not SCSealDB.unlocked)
assert(rendered(1311703,3):find('|T20254:',1,true))
inCombat=false
SlashCmdList.SCSEAL('off')
assert(rendered(1311703,3)=='')
SlashCmdList.SCSEAL('on')
SlashCmdList.SCSEAL('size 80')
assert(SCSealFrame.scale==1.25)
SlashCmdList.SCSEAL('size 999')
assert(SCSealFrame.scale==1.25)
assert(not SCSealFrame.mouse, 'normal clicks intercepted')
SCSealFrame.scripts.OnDragStart(SCSealFrame)
SCSealFrame.scripts.OnDragStop(SCSealFrame)
assert(SCSealDB.x==0, 'drag without Ctrl moved box')
ctrlDown=true; event('MODIFIER_STATE_CHANGED','LCTRL',1)
assert(SCSealFrame.mouse)
assert(rendered(1311703,3)=='', 'live prompt visible over movement preview')
SCSealFrame.scripts.OnDragStart(SCSealFrame)
SCSealFrame:SetPoint('CENTER',UIParent,'CENTER',125,-90)
ctrlDown=false; event('MODIFIER_STATE_CHANGED','LCTRL',0)
assert(SCSealFrame.mouse, 'releasing Ctrl interrupted active drag')
SCSealFrame.scripts.OnDragStop(SCSealFrame)
assert(SCSealDB.x==125 and SCSealDB.y==-90, 'drag position not saved')
assert(not SCSealFrame.mouse)
ctrlDown=true; event('MODIFIER_STATE_CHANGED','RCTRL',1)
inCombat=true; event('PLAYER_REGEN_DISABLED')
assert(not SCSealFrame.mouse, 'Ctrl enabled combat dragging')
inCombat=false; ctrlDown=false; event('PLAYER_REGEN_ENABLED')
auraID=nil; tick(.25)
assert(rendered(1311703,3)~='', 'no-aura debounce missing')
tick(1.1)
assert(rendered(1311703,3)=='', 'absent seal not cleared')
-- Unsupported APIs must not silently use an estimated combat tracker.
C_StringUtil=nil
event('SPELLS_CHANGED')
assert(rendered(1311703,3)=='')
assert(messages[#messages]:find('lacks the native',1,true))
''')
print('PASS merged SCSeal (Lua 5.1): native threshold, both seal directions, proc/secret rejection,')
print('combat restrictions, deferred rebuild, preview, movement, sizing, enable/disable,')
print('absent-aura debounce, and unsupported-client handling.')
