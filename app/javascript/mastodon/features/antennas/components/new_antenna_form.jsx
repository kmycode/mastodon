import PropTypes from 'prop-types';
import { PureComponent } from 'react';

import { defineMessages, injectIntl } from 'react-intl';

import { connect } from 'react-redux';

import { changeAntennaEditorTitle, submitAntennaEditor } from 'mastodon/actions/antennas';
import { Button } from 'mastodon/components/button';

const messages = defineMessages({
  label: { id: 'antennas.new.title_placeholder', defaultMessage: 'New antenna title' },
  title: { id: 'antennas.new.create', defaultMessage: 'Add antenna' },
});

const mapStateToProps = state => ({
  value: state.getIn(['antennaEditor', 'title']),
  disabled: state.getIn(['antennaEditor', 'isSubmitting']),
});

const mapDispatchToProps = dispatch => ({
  onChange: value => dispatch(changeAntennaEditorTitle(value)),
  onSubmit: () => dispatch(submitAntennaEditor(true)),
});

class NewAntennaForm extends PureComponent {

  static propTypes = {
    value: PropTypes.string.isRequired,
    disabled: PropTypes.bool,
    intl: PropTypes.object.isRequired,
    onChange: PropTypes.func.isRequired,
    onSubmit: PropTypes.func.isRequired,
  };

  handleChange = e => {
    this.props.onChange(e.target.value);
  };

  handleSubmit = e => {
    e.preventDefault();
    this.props.onSubmit();
  };

  handleClick = () => {
    this.props.onSubmit();
  };

  render () {
    const { value, disabled, intl } = this.props;

    const label = intl.formatMessage(messages.label);
    const title = intl.formatMessage(messages.title);

    return (
      <form className='column-inline-form' onSubmit={this.handleSubmit}>
        <label>
          <span style={{ display: 'none' }}>{label}</span>

          <input
            className='setting-text'
            value={value}
            disabled={disabled}
            onChange={this.handleChange}
            placeholder={label}
          />
        </label>

        <Button
          disabled={disabled || !value}
          text={title}
          onClick={this.handleClick}
        />
      </form>
    );
  }

}

export default connect(mapStateToProps, mapDispatchToProps)(injectIntl(NewAntennaForm));
