--Types
export type PromptPredicate = (ProximityPrompt) -> boolean

--Public Methods
const function FindAttachment(root: Instance, tag: string): Attachment?
	for _, descendant in root:QueryDescendants(`Attachment.{tag}`) do
		return descendant
	end
	return nil
end

const function FindProximityPrompt(root: Instance, tag: string, predicate: PromptPredicate?): ProximityPrompt?
	for _, descendant in root:QueryDescendants(`ProximityPrompt.{tag}`) do
		if not predicate or predicate(descendant) then
			return descendant
		end
	end
	return nil
end

return {
	findAttachment = FindAttachment,
	findProximityPrompt = FindProximityPrompt,
}
