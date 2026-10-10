class_name SkillCatalog
extends RefCounted

const SIGNATURES := {
	"breaker": ["held_spin", "Giro Sustentado", "Segure Q: gire atacando ao redor por até 2,1 s. Pode andar a 65% da velocidade."],
	"sharpshooter": ["double_shot", "Tiro Duplo", "Cada disparo lança dois arpões paralelos, com 65% do dano cada."],
	"diver": ["double_echo", "Dois Ecos", "O retorno do mergulho deixa dois ecos: impactos adicionais de 35% do dano."],
}
const PASSIVES := {
	"breaker": ["Maré Persistente", "Maré de Ferro dura 12 s e acumula até 4 cargas."],
	"sharpshooter": ["Mira Penetrante", "Mira Firme atravessa até 3 inimigos, preservando o dano por alvo."],
	"diver": ["Fôlego Renovado", "Um mergulho certeiro cura 9 de vida e acelera por 3 s."],
}
const EVASIONS := {"breaker": "Passo do Marinheiro", "sharpshooter": "Passo da Vigia", "diver": "Deslize Abissal"}


static func branches(character_id: String) -> Array[Dictionary]:
	var signature: Array = SIGNATURES.get(character_id, SIGNATURES.breaker)
	var passive: Array = PASSIVES.get(character_id, PASSIVES.breaker)
	return [
		{"name": "ATAQUE", "nodes": [
			{"id": signature[0], "name": signature[1], "description": signature[2], "cost": 100, "requires": ""},
			{"id": "power", "name": "Maré Cortante", "description": "+20% de dano em todos os ataques.", "cost": 150, "requires": signature[0]},
		]},
		{"name": "PASSIVA E ESPECIAL", "nodes": [
			{"id": "passive_mastery", "name": passive[0], "description": passive[1], "cost": 100, "requires": ""},
			{"id": "recharge", "name": "Maré Veloz", "description": "Especial recarrega 20% mais rápido.", "cost": 150, "requires": "passive_mastery"},
		]},
		{"name": "SOBREVIVÊNCIA", "nodes": [
			{"id": "evade_mastery", "name": EVASIONS.get(character_id, EVASIONS.breaker), "description": "Esquiva recarrega em 0,8 s em vez de 1,1 s.", "cost": 100, "requires": ""},
			{"id": "vitality", "name": "Fôlego Profundo", "description": "+25% de vida máxima. Ao aprender, cura o aumento.", "cost": 150, "requires": "evade_mastery"},
		]},
	]


static func find_skill(character_id: String, skill_id: String) -> Dictionary:
	for branch in branches(character_id):
		for skill in branch.nodes:
			if skill.id == skill_id:
				return skill
	return {}
