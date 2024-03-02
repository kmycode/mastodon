import { connect } from 'react-redux';

import { changeComposeVisibility } from '../../../actions/compose';
import { openModal, closeModal } from '../../../actions/modal';
import { isUserTouching } from '../../../is_mobile';
import PrivacyDropdown from '../components/privacy_dropdown';

const mapStateToProps = state => ({
  value: state.getIn(['compose', 'privacy']),
  replyToLimited: state.getIn(['compose', 'reply_to_limited']),
});

const mapDispatchToProps = dispatch => ({

  onChange (value) {
    dispatch(changeComposeVisibility(value));
  },

  isUserTouching,
  onModalOpen: props => dispatch(openModal({  // kmyblue: Do not remove
    modalType: 'ACTIONS',
    modalProps: props,
  })),
  onModalClose: () => dispatch(closeModal({  // kmyblue: Do not remove
    modalType: undefined,
    ignoreFocus: false,
  })),

});

export default connect(mapStateToProps, mapDispatchToProps)(PrivacyDropdown);
