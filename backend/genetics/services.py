"""
Genetics and breeding analysis service.

Provides:
- Pedigree tree building
- Wright's Coefficient of Inbreeding (COI) calculation
- Breeding pair compatibility analysis and suggestions
"""

from datetime import date
from animals.models import Animal


def build_pedigree_tree(animal_id, max_generations=5):
    """
    Build a pedigree tree dictionary for the given animal.

    Returns a nested dict:
    {
        'animal': <Animal>,
        'generation': int,
        'sire': <tree or None>,
        'dam': <tree or None>,
    }
    """
    try:
        animal = Animal.objects.get(pk=animal_id)
    except Animal.DoesNotExist:
        return None
    return _build_node(animal, 0, max_generations)


def _build_node(animal, generation, max_generations):
    node = {
        'animal': animal,
        'generation': generation,
        'sire': None,
        'dam': None,
    }
    if generation < max_generations:
        if animal.sire_id:
            try:
                sire = Animal.objects.get(pk=animal.sire_id)
                node['sire'] = _build_node(sire, generation + 1, max_generations)
            except Animal.DoesNotExist:
                pass
        if animal.dam_id:
            try:
                dam = Animal.objects.get(pk=animal.dam_id)
                node['dam'] = _build_node(dam, generation + 1, max_generations)
            except Animal.DoesNotExist:
                pass
    return node


def calculate_coi(sire_id, dam_id, max_generations=5):
    """
    Calculate Wright's Coefficient of Inbreeding for a hypothetical mating.

    For each common ancestor in both pedigrees:
        COI contribution = (0.5)^(n1 + n2 + 1)
    where n1 = generations from sire to ancestor,
          n2 = generations from dam to ancestor.

    Returns percentage (0-100).
    """
    sire_tree = build_pedigree_tree(sire_id, max_generations)
    dam_tree = build_pedigree_tree(dam_id, max_generations)

    if not sire_tree or not dam_tree:
        return 0.0

    sire_ancestors = _collect_ancestors_with_depth(sire_tree, 0)
    dam_ancestors = _collect_ancestors_with_depth(dam_tree, 0)

    common_ids = set(sire_ancestors.keys()) & set(dam_ancestors.keys())
    if not common_ids:
        return 0.0

    coi = 0.0
    for ancestor_id in common_ids:
        for n1 in sire_ancestors[ancestor_id]:
            for n2 in dam_ancestors[ancestor_id]:
                coi += 0.5 ** (n1 + n2 + 1)

    return min(coi * 100, 100.0)


def _collect_ancestors_with_depth(node, depth):
    """Collect all ancestors with their generational depths."""
    result = {}
    if node.get('sire'):
        sire_id = str(node['sire']['animal'].pk)
        result.setdefault(sire_id, []).append(depth + 1)
        sire_ancestors = _collect_ancestors_with_depth(node['sire'], depth + 1)
        for k, v in sire_ancestors.items():
            result.setdefault(k, []).extend(v)

    if node.get('dam'):
        dam_id = str(node['dam']['animal'].pk)
        result.setdefault(dam_id, []).append(depth + 1)
        dam_ancestors = _collect_ancestors_with_depth(node['dam'], depth + 1)
        for k, v in dam_ancestors.items():
            result.setdefault(k, []).extend(v)

    return result


def generate_breeding_suggestions(animal_id, max_results=10, max_coi=12.5):
    """
    Generate ranked breeding suggestions for the given animal.

    Evaluates all alive, opposite-sex animals of the same species,
    computes COI and compatibility scores, and returns ranked results.
    """
    try:
        animal = Animal.objects.get(pk=animal_id)
    except Animal.DoesNotExist:
        return []

    # Get potential mates: opposite sex, same species, alive
    opposite_sex = Animal.Sex.FEMALE if animal.sex == Animal.Sex.MALE else Animal.Sex.MALE
    candidates = Animal.objects.filter(
        sex=opposite_sex,
        species=animal.species,
        status=Animal.Status.ALIVE,
    ).exclude(pk=animal.pk)

    suggestions = []
    for mate in candidates:
        sire = animal if animal.sex == Animal.Sex.MALE else mate
        dam = animal if animal.sex == Animal.Sex.FEMALE else mate

        coi = calculate_coi(str(sire.pk), str(dam.pk), max_generations=5)
        analysis = _analyze_pairing(sire, dam, coi)

        suggestions.append({
            'sire': sire,
            'dam': dam,
            'compatibility_score': analysis['score'],
            'estimated_coi': coi,
            'score_grade': _score_grade(analysis['score']),
            'coi_rating': _coi_rating(coi),
            'is_recommended': analysis['score'] >= 60 and coi < max_coi,
            'pros': analysis['pros'],
            'cons': analysis['cons'],
            'genetic_risks': analysis['risks'],
            'trait_predictions': analysis['predictions'],
        })

    suggestions.sort(key=lambda s: s['compatibility_score'], reverse=True)
    return suggestions[:max_results]


def _analyze_pairing(sire, dam, coi):
    """Analyze a potential breeding pairing."""
    score = 100.0
    pros = []
    cons = []
    risks = []
    predictions = {}

    # COI scoring
    if coi < 3.0:
        pros.append(f'Very low inbreeding coefficient ({coi:.1f}%)')
    elif coi < 6.25:
        score -= 10
        pros.append(f'Acceptable inbreeding coefficient ({coi:.1f}%)')
    elif coi < 12.5:
        score -= 30
        cons.append(f'Elevated inbreeding coefficient ({coi:.1f}%)')
        risks.append('Increased risk of genetic disorders due to inbreeding')
    else:
        score -= 60
        cons.append(f'Very high inbreeding coefficient ({coi:.1f}%)')
        risks.append('Significant risk of inbreeding depression')
        risks.append('High probability of homozygous genetic defects')

    # Breed compatibility
    if sire.breed == dam.breed:
        pros.append('Same breed - predictable offspring type')
    else:
        score -= 5
        cons.append('Different breeds - offspring traits less predictable')
        predictions['breed_consistency'] = 0.5

    # Age considerations
    today = date.today()
    if sire.date_of_birth:
        sire_years = (today - sire.date_of_birth).days / 365
        if 2 <= sire_years <= 8:
            pros.append('Sire is in prime breeding age')
        elif sire_years < 1:
            score -= 20
            cons.append('Sire may be too young for breeding')
            risks.append('Immature sire may affect offspring quality')
        elif sire_years > 10:
            score -= 10
            cons.append('Sire is of advanced age')

    if dam.date_of_birth:
        dam_years = (today - dam.date_of_birth).days / 365
        if 2 <= dam_years <= 7:
            pros.append('Dam is in prime breeding age')
        elif dam_years < 1.5:
            score -= 25
            cons.append('Dam may be too young for breeding')
            risks.append('Early breeding can harm dam health')
        elif dam_years > 8:
            score -= 15
            cons.append('Dam is of advanced age')
            risks.append('Higher risk of complications for older dam')

    # Size considerations
    if sire.weight and dam.weight:
        weight_ratio = float(sire.weight) / float(dam.weight)
        if weight_ratio > 1.5:
            cons.append('Significant size difference between sire and dam')
            risks.append('Size disparity may cause whelping difficulties')
            score -= 10
        predictions['avg_offspring_weight'] = (
            float(sire.weight) + float(dam.weight)
        ) / 2

    # Genetic diversity bonus
    if sire.breeder_name and dam.breeder_name and sire.breeder_name != dam.breeder_name:
        pros.append('Different breeders - promotes genetic diversity')
        score += 5

    return {
        'score': max(0.0, min(100.0, score)),
        'pros': pros,
        'cons': cons,
        'risks': risks,
        'predictions': predictions,
    }


def _score_grade(score):
    if score >= 90:
        return 'Excellent'
    if score >= 75:
        return 'Good'
    if score >= 60:
        return 'Fair'
    if score >= 40:
        return 'Caution'
    return 'Not Recommended'


def _coi_rating(coi):
    if coi < 3.0:
        return 'Low'
    if coi < 6.25:
        return 'Moderate'
    if coi < 12.5:
        return 'High'
    return 'Very High'


def find_common_ancestors(animal_id_1, animal_id_2, max_generations=5):
    """Find animals that appear in both pedigrees."""
    tree1 = build_pedigree_tree(animal_id_1, max_generations)
    tree2 = build_pedigree_tree(animal_id_2, max_generations)

    if not tree1 or not tree2:
        return []

    ids1 = set(_collect_ancestor_ids(tree1))
    ids2 = set(_collect_ancestor_ids(tree2))
    common = ids1 & ids2

    return list(Animal.objects.filter(pk__in=common))


def _collect_ancestor_ids(node):
    ids = []
    if node.get('sire'):
        ids.append(node['sire']['animal'].pk)
        ids.extend(_collect_ancestor_ids(node['sire']))
    if node.get('dam'):
        ids.append(node['dam']['animal'].pk)
        ids.extend(_collect_ancestor_ids(node['dam']))
    return ids
