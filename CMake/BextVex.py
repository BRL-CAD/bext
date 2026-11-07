"""Shared validation and identity helpers for build-specific VEX."""

import copy
import datetime
import fnmatch
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
from urllib.parse import parse_qsl, urlencode, quote


SCHEMA_VERSION = 1
BUILD_QUALIFIER = 'bext_build'
STATUSES = {'not_affected', 'fixed', 'affected', 'under_investigation'}
JUSTIFICATIONS = {
    'component_not_present', 'vulnerable_code_not_present',
    'vulnerable_code_not_in_execute_path',
    'vulnerable_code_cannot_be_controlled_by_adversary',
    'inline_mitigations_already_exist',
}
HASH_CHUNK_SIZE = 1024 * 1024


def read_json(path):
    def unique_keys(pairs):
        result = {}
        for name, value in pairs:
            if name in result:
                raise ValueError(f'Duplicate JSON field: {name}')
            result[name] = value
        return result

    return json.loads(Path(path).read_text(encoding='utf-8'), object_pairs_hook=unique_keys)


def json_text(value):
    return json.dumps(value, sort_keys=True, indent=2, ensure_ascii=False) + '\n'


def digest(value):
    return hashlib.sha256(json_text(value).encode('utf-8')).hexdigest()


def file_digest(path):
    result = hashlib.sha256()
    with Path(path).open('rb') as source:
        for chunk in iter(lambda: source.read(HASH_CHUNK_SIZE), b''):
            result.update(chunk)
    return result.hexdigest()


def relative_name(value):
    if not isinstance(value, str) or not value or '\\' in value or ':' in value:
        raise ValueError(f'Expected a relative POSIX path: {value!r}')
    path = PurePosixPath(value)
    if path.is_absolute() or '..' in path.parts or path.as_posix() != value:
        raise ValueError(f'Unsafe or non-normalized relative path: {value!r}')
    return value


def inside(root, relative):
    root = Path(root).resolve()
    candidate = root / relative_name(relative)
    try:
        candidate.resolve().relative_to(root)
    except ValueError as error:
        raise ValueError(f'Path escapes its root: {relative}') from error
    return candidate


def timestamp(value):
    if not isinstance(value, str) or not re.fullmatch(r'[0-9]{4}(-[0-9]{2}){2}T[0-9]{2}(:[0-9]{2}){2}Z', value):
        raise ValueError('VEX timestamps must use UTC seconds with a Z suffix')
    datetime.datetime.fromisoformat(value[:-1] + '+00:00')
    return value


def split_build_purl(purl):
    if not isinstance(purl, str) or not purl.startswith('pkg:') or '@' not in purl:
        raise ValueError(f'Expected a versioned PURL: {purl!r}')
    body, separator, fragment = purl.partition('#')
    base, query_separator, query = body.partition('?')
    pairs = parse_qsl(query, keep_blank_values=True)
    builds = [value for key, value in pairs if key == BUILD_QUALIFIER]
    if len(builds) > 1 or (builds and not builds[0]):
        raise ValueError('Ambiguous or empty build qualifier')
    if not builds:
        return purl, None
    remaining = [(key, value) for key, value in pairs if key != BUILD_QUALIFIER]
    source = base
    if remaining:
        source += '?' + urlencode(remaining, quote_via=quote, safe='')
    if separator:
        source += '#' + fragment
    return source, builds[0]


def build_purl(purl, build_id):
    source, previous = split_build_purl(purl)
    if previous:
        raise ValueError('Cannot qualify an already qualified PURL')
    body, separator, fragment = source.partition('#')
    base, _, query = body.partition('?')
    pairs = parse_qsl(query, keep_blank_values=True)
    pairs.append((BUILD_QUALIFIER, build_id))
    result = base + '?' + urlencode(sorted(pairs), quote_via=quote, safe='')
    return result + ('#' + fragment if separator else '')


def purls(package):
    return [ref['referenceLocator'] for ref in package.get('externalRefs', [])
            if ref['referenceType'] == 'purl']


def checked_fields(value, required, optional, label):
    if not isinstance(value, dict):
        raise ValueError(f'{label} must be an object')
    missing = set(required) - value.keys()
    unknown = value.keys() - set(required) - set(optional)
    if missing or unknown:
        raise ValueError(f'{label}: missing {sorted(missing)}, unknown {sorted(unknown)}')


def matches(pattern, value):
    return isinstance(value, str) and re.fullmatch(pattern, value)


def validate_catalog(catalog):
    checked_fields(catalog, ('schemaVersion', 'component', 'target', 'reviews'), (), 'VEX catalog')
    if catalog.get('schemaVersion') != SCHEMA_VERSION:
        raise ValueError('Unsupported VEX review schemaVersion')
    if not matches(r'[a-z0-9][a-z0-9_-]*', catalog['component']):
        raise ValueError('Invalid VEX component')
    if not matches(r'[A-Za-z0-9_]+', catalog['target']):
        raise ValueError('Invalid VEX build target')
    reviews = catalog.get('reviews')
    if not isinstance(reviews, list) or not reviews:
        raise ValueError('A VEX catalog requires reviews')
    identifiers = set()
    for review in reviews:
        checked_fields(review, ('id', 'package', 'sourcePurl', 'vulnerability', 'status',
                                'scope', 'impactStatement', 'reviewedAt', 'references', 'conditions'),
                       ('product', 'justification', 'actionStatement'), 'VEX review')
        identifier = review.get('id', '')
        if not matches(r'[a-z0-9][a-z0-9._-]*', identifier) or identifier in identifiers:
            raise ValueError(f'Invalid or repeated VEX review ID: {identifier}')
        identifiers.add(identifier)
        if not matches(r'CVE-[0-9]{4}-[0-9]{4,}', review['vulnerability']):
            raise ValueError(f'{identifier}: expected a CVE identifier')
        if not matches(r'SPDXRef-[A-Za-z0-9.-]+', review['package']):
            raise ValueError(f'{identifier}: expected a source package ID')
        if split_build_purl(review['sourcePurl'])[1]:
            raise ValueError(f'{identifier}: reviews must name an upstream PURL')
        if not isinstance(review['status'], str) or review['status'] not in STATUSES:
            raise ValueError(f'{identifier}: invalid status')
        if review.get('scope') not in ('component', 'product'):
            raise ValueError(f'{identifier}: scope must be component or product')
        if review['status'] == 'not_affected' and (
                not isinstance(review.get('justification'), str) or
                review['justification'] not in JUSTIFICATIONS):
            raise ValueError(f'{identifier}: a not_affected review requires justification')
        if (review['status'] == 'not_affected' and review['scope'] == 'component' and
                review['justification'] not in ('vulnerable_code_not_present', 'component_not_present')):
            raise ValueError(f'{identifier}: execution-context conclusions require product scope')
        if not isinstance(review['impactStatement'], str) or not review['impactStatement'].strip():
            raise ValueError(f'{identifier}: an impact statement is required')
        if review['status'] == 'affected' and (
                not isinstance(review.get('actionStatement'), str) or not review['actionStatement'].strip()):
            raise ValueError(f'{identifier}: an affected review requires an action statement')
        timestamp(review['reviewedAt'])
        if not isinstance(review['references'], list) or not review['references'] or not all(
                isinstance(url, str) and url.startswith('https://')
                for url in review['references']):
            raise ValueError(f'{identifier}: HTTPS evidence references are required')
        conditions = review['conditions']
        checked_fields(conditions, ('sources', 'inputs', 'requiredInputs', 'stagedFiles', 'requiredArtifacts'),
                       ('forbiddenArtifacts', 'productContext'), f'{identifier} conditions')
        if review['scope'] == 'product' and (
                not review.get('product') or not matches(
                    r'[0-9a-f]{64}', conditions.get('productContext', ''))):
            raise ValueError(f'{identifier}: product scope requires a product and context digest')
        if review['scope'] == 'component' and ('product' in review or 'productContext' in conditions):
            raise ValueError(f'{identifier}: component scope cannot declare a product context')
        for field, length in [('sources', 40), ('inputs', 64), ('stagedFiles', 64)]:
            if not isinstance(conditions.get(field), dict) or not conditions[field]:
                raise ValueError(f'{identifier}: {field} must be a nonempty map')
            for name, value in conditions[field].items():
                relative_name(name)
                if not matches('[0-9a-f]{' + str(length) + '}', value):
                    raise ValueError(f'{identifier}: invalid {field} digest for {name}')
        required = conditions.get('requiredInputs')
        if (not isinstance(required, list) or not required
                or not all(isinstance(name, str) for name in required)
                or not set(required) <= conditions['inputs'].keys()):
            raise ValueError(f'{identifier}: requiredInputs must name reviewed inputs')
        forbidden = conditions.get('forbiddenArtifacts', [])
        if not isinstance(forbidden, list):
            raise ValueError(f'{identifier}: forbiddenArtifacts must be a list')
        for pattern in forbidden:
            relative_name(pattern)
        if not isinstance(conditions['requiredArtifacts'], list) or not conditions['requiredArtifacts']:
            raise ValueError(f'{identifier}: installed artifact requirements are required')
        for alternatives in conditions['requiredArtifacts']:
            if not isinstance(alternatives, list) or not alternatives:
                raise ValueError(f'{identifier}: artifact requirements need alternatives')
            for pattern in alternatives:
                relative_name(pattern)
    return catalog


def validate_capture(capture, component):
    checked_fields(capture, ('schemaVersion', 'component', 'capturedAt', 'sources',
                             'inputs', 'stagedFiles', 'installedArtifacts', 'errors'), (), 'VEX capture')
    if capture['schemaVersion'] != SCHEMA_VERSION or capture['component'] != component:
        raise ValueError(f'Invalid capture identity for {component}')
    timestamp(capture['capturedAt'])
    for field in ('inputs', 'stagedFiles', 'installedArtifacts'):
        if not isinstance(capture[field], dict):
            raise ValueError(f'Capture {field} must be an object')
        for name, value in capture[field].items():
            relative_name(name)
            if value is None and field == 'stagedFiles':
                continue
            if not matches(r'[0-9a-f]{64}', value):
                raise ValueError(f'Invalid captured {field} digest for {name}')
    if not isinstance(capture['sources'], dict):
        raise ValueError('Captured sources must be an object')
    for name, value in capture['sources'].items():
        relative_name(name)
        checked_fields(value, ('revision', 'clean'), (), 'Captured source')
        if value['revision'] is not None and not matches(r'[0-9a-f]{40}', value['revision']):
            raise ValueError(f'Invalid source revision for {name}')
        if not isinstance(value['clean'], bool):
            raise ValueError(f'Invalid source cleanliness for {name}')
    if not isinstance(capture['errors'], list) or not all(isinstance(value, str) for value in capture['errors']):
        raise ValueError('Captured errors must be a list of strings')
    return capture


def load_evidence(registry):
    if registry.get('schemaVersion') != SCHEMA_VERSION:
        raise ValueError('Unsupported VEX evidence registry')
    components = {}
    for entry in registry['components']:
        component = entry['component']
        if component in components:
            raise ValueError(f'Duplicate evidence component: {component}')
        catalog = validate_catalog(read_json(entry['reviews']))
        if catalog['component'] != component:
            raise ValueError('Evidence registry and review component differ')
        path = Path(entry['evidence'])
        capture = read_json(path) if path.exists() else None
        if capture is not None:
            validate_capture(capture, component)
        components[component] = {'component': component,
                                 'reviews': catalog['reviews'], 'capture': capture}
    return components


def exported_evidence(document):
    checked_fields(document, ('schemaVersion', 'product', 'buildId', 'productContext',
                              'sourceDocument', 'components', 'packageIdentities'), (),
                   'Exported VEX evidence')
    if document['schemaVersion'] != SCHEMA_VERSION:
        raise ValueError('Unsupported exported VEX evidence')
    for field in ('buildId', 'productContext'):
        if not matches(r'[0-9a-f]{64}', document[field]):
            raise ValueError(f'Invalid exported {field}')
    if not isinstance(document['components'], list) or not isinstance(document['packageIdentities'], dict):
        raise ValueError('Invalid exported evidence collections')
    components = {}
    for entry in document['components']:
        checked_fields(entry, ('component', 'reviews', 'capture', 'files', 'appliedReviews'), (),
                       'Exported component evidence')
        component = entry['component']
        validate_catalog({'schemaVersion': SCHEMA_VERSION, 'component': component,
                          'target': 'IMPORTED', 'reviews': entry['reviews']})
        if entry['capture'] is not None:
            validate_capture(entry['capture'], component)
        if component in components:
            raise ValueError(f'Duplicate exported component: {component}')
        if not isinstance(entry['files'], list):
            raise ValueError('Exported files must be a list')
        names = set()
        for artifact in entry['files']:
            checked_fields(artifact, ('path', 'sha256'), ('linkTarget',), 'Exported artifact')
            name = relative_name(artifact['path'])
            if name in names or not matches(r'[0-9a-f]{64}', artifact['sha256']):
                raise ValueError(f'Duplicate or invalid exported artifact: {name}')
            names.add(name)
            if 'linkTarget' in artifact:
                relative_name(artifact['linkTarget'])
        applied = entry['appliedReviews']
        known = {review['id'] for review in entry['reviews']}
        if (not isinstance(applied, list) or not all(isinstance(item, str) for item in applied)
                or len(applied) != len(set(applied)) or not set(applied) <= known):
            raise ValueError('Exported appliedReviews must name distinct known reviews')
        if applied and not entry['capture']:
            raise ValueError('Applied reviews require captured evidence')
        components[component] = entry
    return components


def installed_files(manifest, install_root):
    if manifest.get('schema') != 'https://brlcad.org/schema/bext-component-manifest-v2':
        raise ValueError('Expected a finalized component manifest v2')
    files, owners = {}, {}
    for entry in sorted(manifest['files'], key=lambda item: item['path']):
        name, component = relative_name(entry['path']), entry['component']
        if name in owners:
            raise ValueError(f'Duplicate installed artifact: {name}')
        owners[name] = component
        path = inside(install_root, name)
        if not path.is_file():
            raise ValueError(f'Finalized artifact is missing: {name}')
        record = {'path': name, 'sha256': file_digest(path)}
        if path.is_symlink():
            record['linkTarget'] = path.resolve().relative_to(Path(install_root).resolve()).as_posix()
        files.setdefault(component, []).append(record)
    return files


def review_failures(review, capture, artifacts, proof=None):
    if not capture:
        return ['Build evidence is missing; rebuild this component']
    reasons = list(capture['errors'])
    conditions = review['conditions']
    for name, expected in conditions['sources'].items():
        actual = capture['sources'].get(name, {})
        if actual.get('revision') != expected or not actual.get('clean'):
            reasons.append(f'Source revision or cleanliness changed: {name}')
    for name, actual in capture['inputs'].items():
        if conditions['inputs'].get(name) != actual:
            reasons.append(f'Unreviewed or changed source input: {name}')
    for name in conditions['requiredInputs']:
        if name not in capture['inputs']:
            reasons.append(f'Required source input was not used: {name}')
    for name, expected in conditions['stagedFiles'].items():
        if capture['stagedFiles'].get(name) != expected:
            reasons.append(f'Staged source is missing or differs: {name}')
    names = [item['path'] for item in artifacts]
    for pattern in conditions.get('forbiddenArtifacts', []):
        if any(fnmatch.fnmatchcase(name, pattern) for name in names):
            reasons.append(f'Forbidden artifact was included: {pattern}')
    for alternatives in conditions.get('requiredArtifacts', []):
        if not any(fnmatch.fnmatchcase(name, pattern)
                   for name in names for pattern in alternatives):
            reasons.append('Required artifact is missing: ' + ' or '.join(alternatives))
    protected = [artifact for artifact in artifacts
                 if any(fnmatch.fnmatchcase(artifact['path'], pattern)
                        for alternatives in conditions['requiredArtifacts']
                        for pattern in alternatives)]
    if proof is not None and proof.get('captureDigest') != digest(capture):
        reasons.append('Finalization proof belongs to different captured evidence')
    observed = proof['artifacts'] if proof is not None else {
        artifact['path']: artifact['sha256'] for artifact in artifacts}
    for artifact in protected:
        name = artifact['path']
        expected = capture['installedArtifacts'].get(name)
        previous = proof.get('previous', {}) if proof else {}
        previous_hash = previous.get('artifacts', {}).get(name)
        preserved = (previous_hash is not None and
                     review['id'] in previous.get('appliedReviews', []) and
                     observed.get(name) == previous_hash)
        if not expected or (observed.get(name) != expected and not preserved):
            reasons.append(f'Artifact differs from the captured installation: {name}')
    return reasons


def import_failures(previous, current):
    # Downstream packages may omit files, but a changed or additional artifact
    # needs new evidence. Matching only a library's version is insufficient.
    originals = {item['sha256'] for item in previous}
    return [f'Imported component artifact differs: {item["path"]}'
            for item in current if item['sha256'] not in originals]


def build_inventory(source, manifest, files, product):
    result = copy.deepcopy(source)
    packages = {package['SPDXID']: package for package in result['packages']}
    selected, original_ids, builds = {}, {}, {}
    context = digest({'product': product, 'platform': manifest['platform'], 'files': files})
    for record in manifest['packages']:
        component, identifier = record['component'], record['spdx_id']
        output = record.get('output')
        if output not in ('install', 'noinstall'):
            raise ValueError('Component manifest lacks output scope; re-finalize the build')
        if identifier not in packages:
            raise ValueError(f'Unknown package in component manifest: {identifier}')
        if output != 'install' or not files.get(component):
            continue
        if identifier in selected:
            raise ValueError(f'Duplicate selected package: {identifier}')
        package = packages[identifier]
        upstream = purls(package)
        if len(upstream) != 1 or split_build_purl(upstream[0])[1]:
            raise ValueError(f'{identifier}: expected one unqualified source PURL')
        original = record.get('source_spdx_id', identifier)
        build_id = digest({'component': component, 'package': original,
                           'productContext': context,
                           'sourcePurl': upstream[0], 'version': package['versionInfo'],
                           'source': package.get('packageSourceInfo'),
                           'platform': manifest['platform'], 'files': files[component]})
        qualified = build_purl(upstream[0], build_id)
        for reference in package['externalRefs']:
            if reference['referenceType'] == 'purl':
                reference['referenceLocator'] = qualified
        package.setdefault('annotations', []).append({
            'annotationDate': source['creationInfo']['created'],
            'annotationType': 'OTHER', 'annotator': 'Tool: bext-GenerateVex.py',
            'comment': json.dumps({'bext:source:purl': upstream[0],
                                   'bext:build:id': build_id}, sort_keys=True),
        })
        selected[identifier] = component
        key = (component, original)
        if key in original_ids:
            raise ValueError(f'Duplicate imported package identity: {original}')
        original_ids[key] = identifier
        builds[identifier] = {'id': build_id, 'sourcePurl': upstream[0], 'purl': qualified}
    identity = digest({'product': product, 'platform': manifest['platform'],
                       'packages': builds, 'sourceDocument': source['documentNamespace']})
    result['name'] = product + '-build'
    result['documentNamespace'] = 'https://brlcad.org/sbom/build/' + identity
    result['comment'] = ('Finalized installed-product inventory. Qualified PURLs '
                         'identify built variants; annotations retain upstream identities.')
    result['packages'] = [package for identifier, package in packages.items() if identifier in selected]
    result['relationships'] = [
        relation for relation in result['relationships']
        if relation['relatedSpdxElement'] in selected and
        (relation['spdxElementId'] in selected or
         (relation['spdxElementId'] == 'SPDXRef-DOCUMENT' and
          relation['relationshipType'] == 'DESCRIBES'))]
    # Imported inventories can describe only an application root omitted from
    # this dependency view. Every retained package still needs a document link.
    described = {relation['relatedSpdxElement'] for relation in result['relationships']
                 if relation['relationshipType'] == 'DESCRIBES'}
    for identifier in selected.keys() - described:
        result['relationships'].append({'spdxElementId': 'SPDXRef-DOCUMENT',
                                        'relationshipType': 'DESCRIBES',
                                        'relatedSpdxElement': identifier})
    result['relationships'].sort(key=lambda relation: (
        relation['spdxElementId'], relation['relationshipType'], relation['relatedSpdxElement']))
    return result, selected, original_ids, builds, identity, context


def generate(source, manifest, install_root, evidence, aliases, product, author,
             imported=False, proof=None):
    files = installed_files(manifest, install_root)
    inventory, selected, original_ids, builds, identity, context = build_inventory(
        source, manifest, files, product)
    statements, report, reviewed = [], [], set()
    dates = [timestamp(source['creationInfo']['created'])]
    exported = []
    for component, entry in sorted(evidence.items()):
        capture = entry['capture']
        if capture:
            dates.append(timestamp(capture['capturedAt']))
        artifacts = files.get(component, [])
        inherited_failures = import_failures(entry.get('files', []), artifacts) if imported else []
        applied_reviews = []
        for review in entry['reviews']:
            key = (component, review['package'], review['vulnerability'])
            if key in reviewed:
                raise ValueError(f'Duplicate VEX decision: {key}')
            reviewed.add(key)
            identifier = original_ids.get((component, review['package']))
            item = {'review': review['id'], 'component': component,
                    'package': identifier or review['package'],
                    'vulnerability': review['vulnerability']}
            if not identifier:
                item.update(result='not_installed', reasons=[])
                report.append(item)
                continue
            # Imported evidence already records the verified finalized bytes;
            # its original pre-processing hashes need not match a downstream
            # install path. The byte-subset check supplies that binding.
            current_capture = copy.deepcopy(capture)
            if imported and current_capture:
                current_capture['installedArtifacts'] = {
                    item['path']: item['sha256'] for item in artifacts
                    if item['sha256'] in {old['sha256'] for old in entry.get('files', [])}}
            component_proof = proof.get(component) if proof is not None else None
            reasons = review_failures(review, current_capture, artifacts, component_proof) + inherited_failures
            if review['scope'] == 'product' and (
                    imported or review['product'] != product or
                    review['conditions']['productContext'] != context):
                reasons.append('Product context requires local applicability review')
            build = builds[identifier]
            if build['sourcePurl'] != review['sourcePurl']:
                reasons.append('Selected package upstream identity differs from the review')
            if imported and review['id'] not in entry.get('appliedReviews', []):
                reasons.append('Imported evidence did not establish this review')
            if reasons:
                item.update(result='review_needed', reasons=reasons)
            else:
                item.update(result='applied', status=review['status'], reasons=[])
                applied_reviews.append(review['id'])
            report.append(item)
            dates.append(timestamp(review['reviewedAt']))
            products = [{'@id': build['purl']}]
            alias = aliases.get(build['sourcePurl'])
            if alias:
                products.append({'@id': build_purl(alias['targetPurl'], build['id'])})
            statement = {
                'vulnerability': {'name': review['vulnerability']},
                'products': products,
                'status': 'under_investigation' if reasons else review['status'],
                'timestamp': max(capture['capturedAt'] if capture else dates[0], review['reviewedAt']),
                'impact_statement': ('Review conditions require investigation: ' + '; '.join(reasons)
                                     if reasons else review['impactStatement']),
                'status_notes': 'Evidence: ' + '; '.join(review['references']),
            }
            if not reasons and review['status'] == 'not_affected':
                statement['justification'] = review['justification']
            if not reasons and review['status'] == 'affected':
                statement['action_statement'] = review['actionStatement']
            statements.append(statement)
        exported.append({'component': component, 'capture': capture,
                         'reviews': entry['reviews'], 'files': artifacts,
                         'appliedReviews': applied_reviews})
    statements.sort(key=lambda statement: (statement['vulnerability']['name'],
                                            statement['products'][0]['@id']))
    vex = {'@context': 'https://openvex.dev/ns/v0.2.0', 'author': author,
           'timestamp': max(dates), 'version': 1, 'statements': statements}
    vex['@id'] = 'https://brlcad.org/vex/' + digest(vex)
    inventory['creationInfo']['created'] = max(dates)
    if not statements:
        # OpenVEX requires at least one statement. Never leave an older VEX
        # document behind when the current product has no applicable reviews.
        vex = None
    envelope = {'schemaVersion': SCHEMA_VERSION, 'product': product,
                'buildId': identity, 'productContext': context,
                'sourceDocument': source['documentNamespace'],
                'components': exported, 'packageIdentities': builds}
    review_report = {'schemaVersion': SCHEMA_VERSION, 'buildId': identity,
                     'productContext': context,
                     'decisions': report,
                     'unreviewedPackages': sorted(
                         identifier for identifier in selected
                         if not any(item['package'] == identifier for item in report))}
    return inventory, vex, envelope, review_report
