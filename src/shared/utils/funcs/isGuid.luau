--Declarations
const Pattern = "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$"

--Public Methods
const function IsGuid(value: unknown): boolean
	return type(value) == "string" and #value == 36 and string.match(value, Pattern) ~= nil
end

return IsGuid
