import { connect } from 'react-redux';

import { openModal, closeModal } from '../../../actions/modal';
import { isUserTouching } from '../../../is_mobile';
import FeaturedTagsDropdown from '../components/featured_tags_dropdown';

const mapStateToProps = () => ({
});

const mapDispatchToProps = (dispatch, { onPickTag }) => ({

  onChange (value) {
    if (onPickTag) {
      onPickTag(value);
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

export default connect(mapStateToProps, mapDispatchToProps)(FeaturedTagsDropdown);
