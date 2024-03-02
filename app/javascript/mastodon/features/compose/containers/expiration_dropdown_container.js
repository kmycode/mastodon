import { connect } from 'react-redux';

import { openModal, closeModal } from '../../../actions/modal';
import { isUserTouching } from '../../../is_mobile';
import ExpirationDropdown from '../components/expiration_dropdown';

const mapStateToProps = () => ({
});

const mapDispatchToProps = (dispatch, { onPickExpiration }) => ({

  onChange (value) {
    if (onPickExpiration) {
      onPickExpiration(value);
    }
  },

  isUserTouching,
  onModalOpen: props => dispatch(openModal({
    modalType: 'ACTIONS',
    modalProps: props,
  })),
  onModalClose: () => dispatch(closeModal({
    modalType: undefined,
    ignoreFocus: false,
  })),

});

export default connect(mapStateToProps, mapDispatchToProps)(ExpirationDropdown);
