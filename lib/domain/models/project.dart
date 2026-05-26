import 'dart:convert';

/// Project model matching Flutter app structure
class Project {
  final String? projectId;
  final String projectName;
  final String? projectImg;
  final String? projectDescription;
  final List<String> projectRequirements;
  final String? projectStartDate;
  final String? projectEndDate;
  final String? projectMvpDate;
  final List<ProjectDocument> projectDocuments;
  final List<FigmaUrl> projectFigmaUrls;
  final String projectStatus;
  final String projectPriorityLevel;
  final String? projectType;
  final String? projectTeamLeaderId;
  final String? projectManagerId;
  final List<String> projectTeamMemberIds;
  final List<String> projectFollowedByBdeEmployeeIds;
  // Client Details
  final String? clientName;
  final String? companyName;
  final String? clientType;
  final String? clientAddress;
  final String? clientCountry;
  final String? clientPhone;
  // Sub-resources
  final List<ProjectMilestone> projectMilestones;
  final List<ProjectRelease> projectReleases;
  final List<ClientReview> projectClientReviews;
  final ProjectDiscontinuation? projectDiscontinuationDetails;
  final String? projectCreatedBy;
  final DateTime? projectCreatedAt;
  final String? projectUpdatedBy;
  final DateTime? projectUpdatedAt;

  Project({
    this.projectId,
    required this.projectName,
    this.projectImg,
    this.projectDescription,
    this.projectRequirements = const [],
    this.projectStartDate,
    this.projectEndDate,
    this.projectMvpDate,
    this.projectDocuments = const [],
    this.projectFigmaUrls = const [],
    this.projectStatus = 'NOT_STARTED',
    this.projectPriorityLevel = 'MEDIUM',
    this.projectType,
    this.projectTeamLeaderId,
    this.projectManagerId,
    this.projectTeamMemberIds = const [],
    this.projectFollowedByBdeEmployeeIds = const [],
    // Client Details
    this.clientName,
    this.companyName,
    this.clientType,
    this.clientAddress,
    this.clientCountry,
    this.clientPhone,
    // Sub-resources
    this.projectMilestones = const [],
    this.projectReleases = const [],
    this.projectClientReviews = const [],
    this.projectDiscontinuationDetails,
    this.projectCreatedBy,
    this.projectCreatedAt,
    this.projectUpdatedBy,
    this.projectUpdatedAt,
  });

  factory Project.fromMap(Map<String, dynamic> map) {
    return Project(
      projectId: map['project_id']?.toString(),
      projectName: map['project_name']?.toString() ?? '',
      projectImg: map['project_img']?.toString(),
      projectDescription: map['project_description']?.toString(),
      projectRequirements: _parseStringList(map['project_requirements']),
      projectStartDate: map['project_start_date']?.toString(),
      projectEndDate: map['project_end_date']?.toString(),
      projectMvpDate: map['project_mvp_date']?.toString(),
      projectDocuments: _parseDocuments(map['project_documents']),
      projectFigmaUrls: _parseFigmaUrls(map['project_figma_urls']),
      projectStatus: map['project_status']?.toString() ?? 'NOT_STARTED',
      projectPriorityLevel:
          map['project_priority_level']?.toString() ?? 'MEDIUM',
      projectType: map['project_type']?.toString(),
      projectTeamLeaderId: map['project_team_leader_id']?.toString(),
      projectManagerId: map['project_manager_id']?.toString(),
      projectTeamMemberIds: _parseStringList(map['project_team_member_ids']),
      projectFollowedByBdeEmployeeIds: _parseStringList(
        map['project_followed_by_bde_employee_ids'],
      ),
      // Client Details
      clientName: map['client_name']?.toString(),
      companyName: map['company_name']?.toString(),
      clientType: map['client_type']?.toString(),
      clientAddress: map['client_address']?.toString(),
      clientCountry: map['client_country']?.toString(),
      clientPhone: map['client_phone']?.toString(),
      // Sub-resources
      projectMilestones: _parseMilestones(map['project_milestones']),
      projectReleases: _parseReleases(map['project_releases']),
      projectClientReviews: _parseClientReviews(map['project_client_reviews']),
      projectDiscontinuationDetails:
          map['project_discontinuation_details'] != null
          ? ProjectDiscontinuation.fromMap(
              map['project_discontinuation_details'] is String
                  ? jsonDecode(map['project_discontinuation_details'])
                  : map['project_discontinuation_details'],
            )
          : null,
      projectCreatedBy: map['project_created_by']?.toString(),
      projectCreatedAt: map['project_created_at'] != null
          ? DateTime.tryParse(map['project_created_at'].toString())
          : null,
      projectUpdatedBy: map['project_updated_by']?.toString(),
      projectUpdatedAt: map['project_updated_at'] != null
          ? DateTime.tryParse(map['project_updated_at'].toString())
          : null,
    );
  }

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.map((e) => e.toString()).toList();
    if (value is String) {
      try {
        final parsed = jsonDecode(value);
        if (parsed is List) return parsed.map((e) => e.toString()).toList();
      } catch (_) {}
    }
    return [];
  }

  static List<ProjectDocument> _parseDocuments(dynamic value) {
    if (value == null) return [];
    List<dynamic> list;
    if (value is List) {
      list = value;
    } else if (value is String) {
      try {
        list = jsonDecode(value) as List;
      } catch (_) {
        return [];
      }
    } else {
      return [];
    }
    return list
        .map((e) => ProjectDocument.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  static List<FigmaUrl> _parseFigmaUrls(dynamic value) {
    if (value == null) return [];
    List<dynamic> list;
    if (value is List) {
      list = value;
    } else if (value is String) {
      try {
        list = jsonDecode(value) as List;
      } catch (_) {
        return [];
      }
    } else {
      return [];
    }
    return list
        .map((e) => FigmaUrl.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  static List<ProjectMilestone> _parseMilestones(dynamic value) {
    if (value == null) return [];
    List<dynamic> list;
    if (value is List) {
      list = value;
    } else if (value is String) {
      try {
        list = jsonDecode(value) as List;
      } catch (_) {
        return [];
      }
    } else {
      return [];
    }
    return list
        .map((e) => ProjectMilestone.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  static List<ProjectRelease> _parseReleases(dynamic value) {
    if (value == null) return [];
    List<dynamic> list;
    if (value is List) {
      list = value;
    } else if (value is String) {
      try {
        list = jsonDecode(value) as List;
      } catch (_) {
        return [];
      }
    } else {
      return [];
    }
    return list
        .map((e) => ProjectRelease.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  static List<ClientReview> _parseClientReviews(dynamic value) {
    if (value == null) return [];
    List<dynamic> list;
    if (value is List) {
      list = value;
    } else if (value is String) {
      try {
        list = jsonDecode(value) as List;
      } catch (_) {
        return [];
      }
    } else {
      return [];
    }
    return list
        .map((e) => ClientReview.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Map<String, dynamic> toJson() {
    return {
      'project_id': projectId,
      'project_name': projectName,
      'project_img': projectImg,
      'project_description': projectDescription,
      'project_requirements': projectRequirements,
      'project_start_date': projectStartDate,
      'project_end_date': projectEndDate,
      'project_mvp_date': projectMvpDate,
      'project_documents': projectDocuments.map((e) => e.toJson()).toList(),
      'project_figma_urls': projectFigmaUrls.map((e) => e.toJson()).toList(),
      'project_status': projectStatus,
      'project_priority_level': projectPriorityLevel,
      'project_type': projectType,
      'project_team_leader_id': projectTeamLeaderId,
      'project_manager_id': projectManagerId,
      'project_team_member_ids': projectTeamMemberIds,
      'project_followed_by_bde_employee_ids': projectFollowedByBdeEmployeeIds,
      // Client Details
      'client_name': clientName,
      'company_name': companyName,
      'client_type': clientType,
      'client_address': clientAddress,
      'client_country': clientCountry,
      'client_phone': clientPhone,
      // Sub-resources
      'project_milestones': projectMilestones.map((e) => e.toJson()).toList(),
      'project_releases': projectReleases.map((e) => e.toJson()).toList(),
      'project_client_reviews': projectClientReviews
          .map((e) => e.toJson())
          .toList(),
      'project_discontinuation_details': projectDiscontinuationDetails
          ?.toJson(),
      'project_created_by': projectCreatedBy,
      'project_created_at': projectCreatedAt?.toIso8601String(),
      'project_updated_by': projectUpdatedBy,
      'project_updated_at': projectUpdatedAt?.toIso8601String(),
    };
  }

  /// Minimal JSON for list views
  Map<String, dynamic> toListJson() {
    return {
      'project_id': projectId,
      'project_name': projectName,
      'project_img': projectImg,
      'project_status': projectStatus,
      'project_priority_level': projectPriorityLevel,
      'project_type': projectType,
      'project_start_date': projectStartDate,
      'project_end_date': projectEndDate,
      'project_team_leader_id': projectTeamLeaderId,
      'team_member_count': projectTeamMemberIds.length,
      // Client Details
      'client_name': clientName,
      'company_name': companyName,
      'client_type': clientType,
    };
  }
}

// ===================== PROJECT DOCUMENT =====================

class ProjectDocument {
  final String? documentId;
  final String? projectId;
  final String documentName;
  final String documentUrl;
  final String? documentType;
  final String? createdBy;
  final DateTime? createdAt;
  final String? updatedBy;
  final DateTime? updatedAt;

  ProjectDocument({
    this.documentId,
    this.projectId,
    required this.documentName,
    required this.documentUrl,
    this.documentType,
    this.createdBy,
    this.createdAt,
    this.updatedBy,
    this.updatedAt,
  });

  factory ProjectDocument.fromMap(Map<String, dynamic> map) {
    return ProjectDocument(
      documentId: map['document_id']?.toString(),
      projectId: map['project_id']?.toString(),
      documentName: map['document_name']?.toString() ?? '',
      documentUrl: map['document_url']?.toString() ?? '',
      documentType: map['document_type']?.toString(),
      createdBy: map['created_by']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      updatedBy: map['updated_by']?.toString(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'document_id': documentId,
      'project_id': projectId,
      'document_name': documentName,
      'document_url': documentUrl,
      'document_type': documentType,
      'created_by': createdBy,
      'created_at': createdAt?.toIso8601String(),
      'updated_by': updatedBy,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

// ===================== FIGMA URL =====================

class FigmaUrl {
  final String? figmaUrlId;
  final String? projectId;
  final String figmaUrlName;
  final String figmaUrl;
  final String? createdBy;
  final DateTime? createdAt;
  final String? updatedBy;
  final DateTime? updatedAt;

  FigmaUrl({
    this.figmaUrlId,
    this.projectId,
    required this.figmaUrlName,
    required this.figmaUrl,
    this.createdBy,
    this.createdAt,
    this.updatedBy,
    this.updatedAt,
  });

  factory FigmaUrl.fromMap(Map<String, dynamic> map) {
    return FigmaUrl(
      figmaUrlId: map['figma_url_id']?.toString(),
      projectId: map['project_id']?.toString(),
      figmaUrlName: map['figma_url_name']?.toString() ?? '',
      figmaUrl: map['figma_url']?.toString() ?? '',
      createdBy: map['created_by']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      updatedBy: map['updated_by']?.toString(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'figma_url_id': figmaUrlId,
      'project_id': projectId,
      'figma_url_name': figmaUrlName,
      'figma_url': figmaUrl,
      'created_by': createdBy,
      'created_at': createdAt?.toIso8601String(),
      'updated_by': updatedBy,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

// ===================== PROJECT RELEASE =====================

class ProjectRelease {
  final String? projectReleaseId;
  final String? projectId;
  final String projectReleaseTitle;
  final String? projectReleasePlannedDate;
  final String? projectReleaseActualDate;
  final String? projectReleaseDevCutoffDate;
  final String? projectReleaseQcCutoffDate;
  final String? projectReleaseNotes;
  final List<ReleaseAttachment> projectReleaseAttachments;
  final String? projectReleaseCreatedBy;
  final DateTime? projectReleaseCreatedAt;
  final String? projectReleaseUpdatedBy;
  final DateTime? projectReleaseUpdatedAt;

  ProjectRelease({
    this.projectReleaseId,
    this.projectId,
    required this.projectReleaseTitle,
    this.projectReleasePlannedDate,
    this.projectReleaseActualDate,
    this.projectReleaseDevCutoffDate,
    this.projectReleaseQcCutoffDate,
    this.projectReleaseNotes,
    this.projectReleaseAttachments = const [],
    this.projectReleaseCreatedBy,
    this.projectReleaseCreatedAt,
    this.projectReleaseUpdatedBy,
    this.projectReleaseUpdatedAt,
  });

  factory ProjectRelease.fromMap(Map<String, dynamic> map) {
    return ProjectRelease(
      projectReleaseId: map['project_release_id']?.toString(),
      projectId: map['project_id']?.toString(),
      projectReleaseTitle: map['project_release_title']?.toString() ?? '',
      projectReleasePlannedDate: map['project_release_planned_date']
          ?.toString(),
      projectReleaseActualDate: map['project_release_actual_date']?.toString(),
      projectReleaseDevCutoffDate: map['project_release_dev_cutoff_date']
          ?.toString(),
      projectReleaseQcCutoffDate: map['project_release_qc_cutoff_date']
          ?.toString(),
      projectReleaseNotes: map['project_release_notes']?.toString(),
      projectReleaseAttachments: _parseAttachments(
        map['project_release_attachments'],
      ),
      projectReleaseCreatedBy: map['project_release_created_by']?.toString(),
      projectReleaseCreatedAt: map['project_release_created_at'] != null
          ? DateTime.tryParse(map['project_release_created_at'].toString())
          : null,
      projectReleaseUpdatedBy: map['project_release_updated_by']?.toString(),
      projectReleaseUpdatedAt: map['project_release_updated_at'] != null
          ? DateTime.tryParse(map['project_release_updated_at'].toString())
          : null,
    );
  }

  static List<ReleaseAttachment> _parseAttachments(dynamic value) {
    if (value == null) return [];
    List<dynamic> list;
    if (value is List) {
      list = value;
    } else if (value is String) {
      try {
        list = jsonDecode(value) as List;
      } catch (_) {
        return [];
      }
    } else {
      return [];
    }
    return list
        .map((e) => ReleaseAttachment.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Map<String, dynamic> toJson() {
    return {
      'project_release_id': projectReleaseId,
      'project_id': projectId,
      'project_release_title': projectReleaseTitle,
      'project_release_planned_date': projectReleasePlannedDate,
      'project_release_actual_date': projectReleaseActualDate,
      'project_release_dev_cutoff_date': projectReleaseDevCutoffDate,
      'project_release_qc_cutoff_date': projectReleaseQcCutoffDate,
      'project_release_notes': projectReleaseNotes,
      'project_release_attachments': projectReleaseAttachments
          .map((e) => e.toJson())
          .toList(),
      'project_release_created_by': projectReleaseCreatedBy,
      'project_release_created_at': projectReleaseCreatedAt?.toIso8601String(),
      'project_release_updated_by': projectReleaseUpdatedBy,
      'project_release_updated_at': projectReleaseUpdatedAt?.toIso8601String(),
    };
  }
}

// ===================== RELEASE ATTACHMENT =====================

class ReleaseAttachment {
  final String? releaseAttachmentId;
  final String? projectReleaseId;
  final String? projectId;
  final String releaseAttachmentType;
  final String releaseAttachmentValue;
  final String? releaseAttachmentCreatedBy;
  final DateTime? releaseAttachmentCreatedAt;
  final String? releaseAttachmentUpdatedBy;
  final DateTime? releaseAttachmentUpdatedAt;

  ReleaseAttachment({
    this.releaseAttachmentId,
    this.projectReleaseId,
    this.projectId,
    required this.releaseAttachmentType,
    required this.releaseAttachmentValue,
    this.releaseAttachmentCreatedBy,
    this.releaseAttachmentCreatedAt,
    this.releaseAttachmentUpdatedBy,
    this.releaseAttachmentUpdatedAt,
  });

  factory ReleaseAttachment.fromMap(Map<String, dynamic> map) {
    return ReleaseAttachment(
      releaseAttachmentId: map['release_attachment_id']?.toString(),
      projectReleaseId: map['project_release_id']?.toString(),
      projectId: map['project_id']?.toString(),
      releaseAttachmentType: map['release_attachment_type']?.toString() ?? '',
      releaseAttachmentValue: map['release_attachment_value']?.toString() ?? '',
      releaseAttachmentCreatedBy: map['release_attachment_created_by']
          ?.toString(),
      releaseAttachmentCreatedAt: map['release_attachment_created_at'] != null
          ? DateTime.tryParse(map['release_attachment_created_at'].toString())
          : null,
      releaseAttachmentUpdatedBy: map['release_attachment_updated_by']
          ?.toString(),
      releaseAttachmentUpdatedAt: map['release_attachment_updated_at'] != null
          ? DateTime.tryParse(map['release_attachment_updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'release_attachment_id': releaseAttachmentId,
      'project_release_id': projectReleaseId,
      'project_id': projectId,
      'release_attachment_type': releaseAttachmentType,
      'release_attachment_value': releaseAttachmentValue,
      'release_attachment_created_by': releaseAttachmentCreatedBy,
      'release_attachment_created_at': releaseAttachmentCreatedAt
          ?.toIso8601String(),
      'release_attachment_updated_by': releaseAttachmentUpdatedBy,
      'release_attachment_updated_at': releaseAttachmentUpdatedAt
          ?.toIso8601String(),
    };
  }
}

// ===================== PROJECT MILESTONE =====================

class ProjectMilestone {
  final String? projectMilestoneId;
  final String? projectId;
  final String projectMilestoneTitle;
  final String? projectMilestoneAchievementDescription;
  final String? projectMilestoneCreatedBy;
  final DateTime? projectMilestoneCreatedAt;
  final String? projectMilestoneUpdatedBy;
  final DateTime? projectMilestoneUpdatedAt;

  ProjectMilestone({
    this.projectMilestoneId,
    this.projectId,
    required this.projectMilestoneTitle,
    this.projectMilestoneAchievementDescription,
    this.projectMilestoneCreatedBy,
    this.projectMilestoneCreatedAt,
    this.projectMilestoneUpdatedBy,
    this.projectMilestoneUpdatedAt,
  });

  factory ProjectMilestone.fromMap(Map<String, dynamic> map) {
    return ProjectMilestone(
      projectMilestoneId: map['project_milestone_id']?.toString(),
      projectId: map['project_id']?.toString(),
      projectMilestoneTitle: map['project_milestone_title']?.toString() ?? '',
      projectMilestoneAchievementDescription:
          map['project_milestone_achievement_description']?.toString(),
      projectMilestoneCreatedBy: map['project_milestone_created_by']
          ?.toString(),
      projectMilestoneCreatedAt: map['project_milestone_created_at'] != null
          ? DateTime.tryParse(map['project_milestone_created_at'].toString())
          : null,
      projectMilestoneUpdatedBy: map['project_milestone_updated_by']
          ?.toString(),
      projectMilestoneUpdatedAt: map['project_milestone_updated_at'] != null
          ? DateTime.tryParse(map['project_milestone_updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'project_milestone_id': projectMilestoneId,
      'project_id': projectId,
      'project_milestone_title': projectMilestoneTitle,
      'project_milestone_achievement_description':
          projectMilestoneAchievementDescription,
      'project_milestone_created_by': projectMilestoneCreatedBy,
      'project_milestone_created_at': projectMilestoneCreatedAt
          ?.toIso8601String(),
      'project_milestone_updated_by': projectMilestoneUpdatedBy,
      'project_milestone_updated_at': projectMilestoneUpdatedAt
          ?.toIso8601String(),
    };
  }
}

// ===================== CLIENT REVIEW =====================

class ClientReview {
  final String? clientReviewId;
  final String? projectId;
  final String clientReviewComment;
  final int clientReviewRating;
  final String? clientReviewCreatedBy;
  final DateTime? clientReviewCreatedAt;
  final String? clientReviewUpdatedBy;
  final DateTime? clientReviewUpdatedAt;

  ClientReview({
    this.clientReviewId,
    this.projectId,
    required this.clientReviewComment,
    required this.clientReviewRating,
    this.clientReviewCreatedBy,
    this.clientReviewCreatedAt,
    this.clientReviewUpdatedBy,
    this.clientReviewUpdatedAt,
  });

  factory ClientReview.fromMap(Map<String, dynamic> map) {
    return ClientReview(
      clientReviewId: map['client_review_id']?.toString(),
      projectId: map['project_id']?.toString(),
      clientReviewComment: map['client_review_comment']?.toString() ?? '',
      clientReviewRating: (map['client_review_rating'] as num?)?.toInt() ?? 0,
      clientReviewCreatedBy: map['client_review_created_by']?.toString(),
      clientReviewCreatedAt: map['client_review_created_at'] != null
          ? DateTime.tryParse(map['client_review_created_at'].toString())
          : null,
      clientReviewUpdatedBy: map['client_review_updated_by']?.toString(),
      clientReviewUpdatedAt: map['client_review_updated_at'] != null
          ? DateTime.tryParse(map['client_review_updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'client_review_id': clientReviewId,
      'project_id': projectId,
      'client_review_comment': clientReviewComment,
      'client_review_rating': clientReviewRating,
      'client_review_created_by': clientReviewCreatedBy,
      'client_review_created_at': clientReviewCreatedAt?.toIso8601String(),
      'client_review_updated_by': clientReviewUpdatedBy,
      'client_review_updated_at': clientReviewUpdatedAt?.toIso8601String(),
    };
  }
}

// ===================== PROJECT DISCONTINUATION =====================

class ProjectDiscontinuation {
  final String? projectDiscontinuationId;
  final String projectId;
  final String projectDiscontinuationReason;
  final String projectDiscontinuationBy;
  final DateTime? projectDiscontinuationAt;
  final String? projectDiscontinuationRemarks;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ProjectDiscontinuation({
    this.projectDiscontinuationId,
    required this.projectId,
    required this.projectDiscontinuationReason,
    required this.projectDiscontinuationBy,
    this.projectDiscontinuationAt,
    this.projectDiscontinuationRemarks,
    this.createdAt,
    this.updatedAt,
  });

  factory ProjectDiscontinuation.fromMap(Map<String, dynamic> map) {
    return ProjectDiscontinuation(
      projectDiscontinuationId: map['project_discontinuation_id']?.toString(),
      projectId: map['project_id']?.toString() ?? '',
      projectDiscontinuationReason:
          map['project_discontinuation_reason']?.toString() ?? '',
      projectDiscontinuationBy:
          map['project_discontinuation_by']?.toString() ?? '',
      projectDiscontinuationAt: map['project_discontinuation_at'] != null
          ? DateTime.tryParse(map['project_discontinuation_at'].toString())
          : null,
      projectDiscontinuationRemarks: map['project_discontinuation_remarks']
          ?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'project_discontinuation_id': projectDiscontinuationId,
      'project_id': projectId,
      'project_discontinuation_reason': projectDiscontinuationReason,
      'project_discontinuation_by': projectDiscontinuationBy,
      'project_discontinuation_at': projectDiscontinuationAt?.toIso8601String(),
      'project_discontinuation_remarks': projectDiscontinuationRemarks,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

// ===================== ENUMS =====================

class ProjectStatus {
  static const String notStarted = 'NOT_STARTED';
  static const String inProgress = 'IN_PROGRESS';
  static const String completed = 'COMPLETED';
  static const String onHold = 'ON_HOLD';
  static const String discontinued = 'DISCONTINUED';

  static const List<String> values = [
    notStarted,
    inProgress,
    completed,
    onHold,
    discontinued,
  ];

  static bool isValid(String status) => values.contains(status);
}

class PriorityLevel {
  static const String low = 'LOW';
  static const String medium = 'MEDIUM';
  static const String high = 'HIGH';
  static const String critical = 'CRITICAL';

  static const List<String> values = [low, medium, high, critical];

  static bool isValid(String level) => values.contains(level);
}
