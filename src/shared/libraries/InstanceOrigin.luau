--Public Methods
const function GetCFrame(origin: Instance): CFrame?
	if origin:IsA("Attachment") then
		return origin.WorldCFrame
	end
	if origin:IsA("BasePart") then
		return origin.CFrame
	end
	if origin:IsA("Model") then
		return origin:GetPivot()
	end
	return nil
end

const function GetPosition(origin: Instance): Vector3?
	const originCFrame = GetCFrame(origin)
	return if originCFrame then originCFrame.Position else nil
end

return {
	getCFrame = GetCFrame,
	getPosition = GetPosition,
}
