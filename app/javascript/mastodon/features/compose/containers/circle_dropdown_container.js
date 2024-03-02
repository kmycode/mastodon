import { connect } from 'react-redux';

import { changeCircle } from '../../../actions/compose';
import { openModal, closeModal } from '../../../actions/modal';
import { isUserTouching } from '../../../is_mobile';
import CircleDropdown from '../components/circle_dropdown';

const mapStateToProps = state => ({
  unavailable: state.getIn(['compose', 'privacy']) !== 'circle' || !!state.getIn(['compose', 'id']),
  value: state.getIn(['compose', 'searchability']),
  circles: state.get('circles'),
  circleId: state.getIn(['compose', 'circle_id']),
});

const mapDispatchToProps = dispatch => ({

  onChange (circleId) {
    dispatch(changeCircle(circleId));
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

export default connect(mapStateToProps, mapDispatchToProps)(CircleDropdown);
