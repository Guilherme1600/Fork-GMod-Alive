local GA=GModAlive
GA.MaxVoiceBytes=3000000
GA.VoiceChunkSize=48000
GA.MaxVoiceSeconds=15
local function u16(s,p) local a,b=s:byte(p,p+1) return b and a+b*256 or nil end
local function u32(s,p) local a,b,c,d=s:byte(p,p+3) return d and a+b*256+c*65536+d*16777216 or nil end
local function le(n,bytes)
    local out={} for i=1,bytes do out[i]=string.char(n%256) n=math.floor(n/256) end return table.concat(out)
end
function GA.ParseVoiceWav(raw)
    if not isstring(raw) or #raw<44 or #raw>GA.MaxVoiceBytes or raw:sub(1,4)~="RIFF" or raw:sub(9,12)~="WAVE" then return nil,"Invalid or oversized microphone WAV." end
    local pos,fmt,pcm=13,nil,nil
    while pos+7<=#raw do
        local tag,size=raw:sub(pos,pos+3),u32(raw,pos+4) local first=pos+8
        if not size or first+size-1>#raw then return nil,"Microphone WAV is still incomplete." end
        if tag=="fmt " and size>=16 then fmt={codec=u16(raw,first),channels=u16(raw,first+2),rate=u32(raw,first+4),bits=u16(raw,first+14)}
        elseif tag=="data" then pcm=raw:sub(first,first+size-1) end
        pos=first+size+size%2
    end
    if not fmt or not pcm or #pcm==0 or fmt.codec~=1 or fmt.bits~=16 or fmt.channels<1 or fmt.channels>2 or fmt.rate<8000 or fmt.rate>96000 or #pcm%(2*fmt.channels)~=0 then return nil,"Unsupported microphone WAV format." end
    fmt.duration=#pcm/(fmt.rate*fmt.channels*2)
    if fmt.duration<0.25 or fmt.duration>GA.MaxVoiceSeconds+2 then return nil,"Microphone recording is too short or too long." end
    local energy,count=0,0
    for i=1,#pcm,2*fmt.channels*math.max(1,math.floor(fmt.rate/8000)) do
        local sample=u16(pcm,i) if sample>=32768 then sample=sample-65536 end
        energy=energy+(sample/32768)^2 count=count+1
    end
    fmt.rms=math.sqrt(energy/math.max(count,1))
    if fmt.rms<0.002 then return nil,"Microphone recording contains only silence." end
    fmt.pcm=pcm return fmt
end
function GA.PackVoiceWav(pcm,rate,channels)
    return "RIFF"..le(36+#pcm,4).."WAVEfmt "..le(16,4)..le(1,2)..le(channels,2)..le(rate,4)..le(rate*channels*2,4)..le(channels*2,2)..le(16,2).."data"..le(#pcm,4)..pcm
end
