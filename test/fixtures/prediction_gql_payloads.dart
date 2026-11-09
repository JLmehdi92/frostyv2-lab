Map<String, Object?> predictionAccessResponse({
  bool? hasAcceptedTerms = true,
  String? restriction,
}) => {
  'data': {
    'currentUser': {
      'id': '1000',
      'predictionsSettings': hasAcceptedTerms == null
          ? null
          : {
              'hasAcceptedTOS': hasAcceptedTerms,
              'isTemporaryChatBadgeEnabled': false,
            },
    },
    'predictionEvent': {
      'id': 'event-1',
      'self': {'restriction': restriction},
    },
  },
};

const anonymousPredictionAccessResponse = {
  'errors': [
    {
      'message': 'server error',
      'path': ['predictionEvent'],
    },
  ],
  'data': {'currentUser': null, 'predictionEvent': null},
};

const acceptPredictionTermsResponse = {
  'data': {
    'updateUserPredictionSettings': {
      'error': null,
      'settings': {'hasAcceptedTOS': true, 'isTemporaryChatBadgeEnabled': true},
    },
  },
};
