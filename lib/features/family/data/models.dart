/// Family domain models. Account (user), Person, and Story are separate
/// concepts: a person exists in the family network without any account.
class FamilySpace {
  const FamilySpace({
    required this.id,
    required this.name,
    required this.inviteCode,
  });

  factory FamilySpace.fromJson(Map<String, dynamic> j) => FamilySpace(
    id: j['id'] as String,
    name: j['name'] as String,
    inviteCode: j['invite_code'] as String? ?? '',
  );
  final String id;
  final String name;
  final String inviteCode;
}

class FamilyMember {
  const FamilyMember({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.role,
    this.personId,
  });
  final String id;
  final String userId;
  final String displayName;
  final String role; // 'owner' | 'member'
  final String? personId;

  bool get isOwner => role == 'owner';
}

class Person {
  const Person({
    required this.id,
    required this.spaceId,
    required this.fullName,
    required this.createdBy,
    this.photoPath,
    this.approxBirthDate,
    this.approxDeathDate,
    this.bio,
    this.linkedUserId,
  });

  factory Person.fromJson(Map<String, dynamic> j) => Person(
    id: j['id'] as String,
    spaceId: j['space_id'] as String,
    fullName: j['full_name'] as String,
    photoPath: j['photo_path'] as String?,
    approxBirthDate: j['approx_birth_date'] as String?,
    approxDeathDate: j['approx_death_date'] as String?,
    bio: j['bio'] as String?,
    linkedUserId: j['linked_user_id'] as String?,
    createdBy: j['created_by'] as String,
  );
  final String id;
  final String spaceId;
  final String fullName;
  final String? photoPath;
  final String? approxBirthDate;
  final String? approxDeathDate;
  final String? bio;
  final String? linkedUserId;
  final String createdBy;
}

enum RelationshipType { parent, child, spouse, sibling }

enum RelationshipStatus { pending, confirmed }

class Relationship {
  const Relationship({
    required this.id,
    required this.personId,
    required this.relatedPersonId,
    required this.type,
    required this.status,
  });

  factory Relationship.fromJson(Map<String, dynamic> j) => Relationship(
    id: j['id'] as String,
    personId: j['person_id'] as String,
    relatedPersonId: j['related_person_id'] as String,
    type: RelationshipType.values.byName(j['type'] as String),
    status: RelationshipStatus.values.byName(j['status'] as String),
  );
  final String id;
  final String personId;
  final String relatedPersonId;
  final RelationshipType type;
  final RelationshipStatus status;
}
